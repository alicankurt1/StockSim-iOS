import Foundation
import Testing
import Domain
@testable import MarketData

private let thyao = Symbol("THYAO")
private let sise = Symbol("SISE")

private func decode(_ json: String) throws -> YahooChartResponse.Result {
    try #require(try JSONDecoder().decode(YahooChartResponse.self, from: Fixture.data(json)).chart.result?.first)
}

/// Yanıt → Domain dönüşümü: Codable uç durumları.
struct YahooParsingTests {

    @Test func quoteUsesMarketPriceAndPreviousClose() throws {
        let quote = try decode(Fixture.intraday).quote(for: thyao)

        #expect(quote.price == Money(Decimal(string: "273.5")!))
        #expect(quote.previousClose == Money(Decimal(string: "276.75")!))
        #expect(quote.timestamp == Date(timeIntervalSince1970: 1792163398))
    }

    /// İşlem olmayan saat (`null`) atlanır; geri kalan mumlar sırasıyla gelir.
    @Test func candlesSkipNullRows() throws {
        let candles = try decode(Fixture.intraday).candles()

        #expect(candles.count == 2)
        #expect(candles.map(\.date) == [Date(timeIntervalSince1970: 1792132200), Date(timeIntervalSince1970: 1792139400)])
        #expect(candles.first?.close == Money(Decimal(string: "274.25")!))
    }

    /// Tatil: mum yok ama fiyat var; uygulama çökmeden boş grafik gösterir.
    @Test func holidayHasQuoteButNoCandles() throws {
        let result = try decode(Fixture.holiday)

        #expect(result.candles().isEmpty)
        #expect(try result.quote(for: thyao).price == Money(270))
    }

    /// `regularMarketPrice` yoksa son kapanış; Double gürültüsü kuruşa yuvarlanır.
    @Test func missingMarketPriceFallsBackToLastCloseRounded() throws {
        let quote = try decode(Fixture.missingMarketPrice).quote(for: sise)

        #expect(quote.price == Money(Decimal(string: "41.72")!))
        #expect(quote.previousClose == Money(Decimal(string: "41.5")!))
    }

    @Test(arguments: [(287.5, "287.5"), (41.720000001, "41.72"), (0.005, "0.01"), (999.994, "999.99")])
    func doublesBecomeExactCents(value: Double, expected: String) {
        #expect(YahooMoney.money(value) == Money(Decimal(string: expected)!))
    }
}

struct YahooMarketProviderTests {

    /// Grafik aralığı → doğru Yahoo isteği (".IS" eki dahil).
    @Test(arguments: [
        (ChartRange.day, "range=1d&interval=5m"),
        (.week, "range=5d&interval=60m"),
        (.month, "range=1mo&interval=1d"),
        (.year, "range=1y&interval=1wk"),
    ])
    func historyRequestsTheRightRange(range: ChartRange, query: String) async throws {
        let client = StubHTTPClient()
        let provider = YahooMarketProvider(client: client)

        _ = try await provider.history(for: thyao, range: range)

        let url = try #require(client.requestedURLs.first)
        #expect(url.path.hasSuffix("/v8/finance/chart/THYAO.IS"))
        #expect(url.query == query)
    }

    /// Önbellek: süre dolmadan aynı istek tekrar atılmaz; dolunca atılır.
    @Test func historyIsCachedUntilItExpires() async throws {
        let client = StubHTTPClient()
        let clock = MutableClock()
        let provider = YahooMarketProvider(client: client, cacheLifetime: 60, now: { clock.now })

        _ = try await provider.history(for: thyao, range: .day)
        _ = try await provider.history(for: thyao, range: .day)
        #expect(client.requestCount == 1)

        clock.advance(by: 61)
        _ = try await provider.history(for: thyao, range: .day)
        #expect(client.requestCount == 2)
    }

    @Test func unknownSymbolThrows() async {
        let client = StubHTTPClient()
        client.enqueue("NOPE.IS", .json(Fixture.notFound, status: 404))
        let provider = YahooMarketProvider(client: client)

        await #expect(throws: MarketDataError.unknownSymbol(Symbol("NOPE"))) {
            try await provider.history(for: Symbol("NOPE"), range: .day)
        }
    }

    /// Bir hissenin hatası diğerlerini engellemez; sıra korunur.
    @Test func quotesSurvivePartialFailure() async throws {
        let client = StubHTTPClient()
        client.enqueue("THYAO.IS", .json("{}", status: 500))
        client.enqueue("SISE.IS", .json(Fixture.missingMarketPrice))
        let provider = YahooMarketProvider(client: client)

        let quotes = try await provider.quotes(for: [thyao, sise])

        #expect(quotes.map(\.symbol) == [sise])
    }

    @Test func allQuotesFailingThrows() async {
        let provider = YahooMarketProvider(client: StubHTTPClient(fallback: .failure(.notConnectedToInternet)))

        await #expect(throws: MarketDataError.unavailable("No quotes")) {
            try await provider.quotes(for: [thyao])
        }
    }

    /// Canlı akış (polling): fiyat → ağ koptu → geri geldi + fiyat.
    @Test func updatesReportInterruptionAndRecovery() async throws {
        let client = StubHTTPClient()
        client.enqueue("THYAO.IS", .json(Fixture.intraday), .failure(.notConnectedToInternet), .failure(.timedOut), .json(Fixture.intraday))
        let provider = YahooMarketProvider(client: client, sleep: { _ in await Task.yield() })

        var iterator = await provider.updates(for: [thyao]).makeAsyncIterator()
        var received: [MarketUpdate] = []
        for _ in 0..<4 {
            if let update = await iterator.next() { received.append(update) }
        }

        guard received.count == 4, case .quote = received[0], case .quote = received[3] else {
            Issue.record("Beklenmeyen akış: \(received)")
            return
        }
        // İki ardışık hata tek bir "koptu" olayı üretir.
        #expect(received[1] == .feedInterrupted)
        #expect(received[2] == .feedRestored)
    }

    @Test func instrumentsComeFromTheCatalog() async {
        #expect(await YahooMarketProvider(client: StubHTTPClient()).instruments() == BistCatalog.instruments)
    }
}

/// Testte zamanı elle ilerletmek için.
private final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date { lock.withLock { current } }
    func advance(by seconds: TimeInterval) { lock.withLock { current += seconds } }
}
