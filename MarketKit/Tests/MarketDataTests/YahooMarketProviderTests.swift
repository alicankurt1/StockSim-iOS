// Sadece Debug derlemesi (Package.swift → REAL_DATA).
#if REAL_DATA
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
    /// Gerçek veride görülen hata: gün ortasında tek bir mum dünkü kapanışla (≈%1,3 yukarıda) geliyor.
    @Test func isolatedSpikeIsRemoved() {
        let closes: [Decimal] = [273.25, 273.0, 276.75, 273.25, 273.5]
        let filtered = YahooChartResponse.Result.removingIsolatedSpikes(candles(closes))
        #expect(filtered.map(\.close.amount) == [273.25, 273.0, 273.25, 273.5])
    }

    /// Gerçek sert düşüş ardışık mumlarda sürer: tekil değil, dokunulmaz.
    @Test func sustainedMoveIsKept() {
        let closes: [Decimal] = [100, 100.2, 95, 94.8, 95.1]
        let filtered = YahooChartResponse.Result.removingIsolatedSpikes(candles(closes))
        #expect(filtered.count == closes.count)
    }

    /// İlk ve son mum asla atılmaz (komşusu tek taraflı).
    @Test func edgesAreKept() {
        let closes: [Decimal] = [110, 100, 100.1, 100, 90]
        #expect(YahooChartResponse.Result.removingIsolatedSpikes(candles(closes)).count == 5)
    }

    private func candles(_ closes: [Decimal]) -> [Candle] {
        closes.enumerated().map { index, close in
            Candle(date: Date(timeIntervalSince1970: Double(index) * 300),
                   open: Money(close), high: Money(close), low: Money(close), close: Money(close))
        }
    }

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

    /// Sadece İstanbul hisse senetleri; ".IS" eki atılır; uzun isim yoksa kısa isim.
    @Test func searchKeepsOnlyIstanbulEquities() async throws {
        let client = StubHTTPClient()
        client.enqueue("search", .json(Fixture.search))
        let provider = YahooMarketProvider(client: client)

        let results = try await provider.searchInstruments(matching: "aks")

        #expect(results.map(\.symbol.rawValue) == ["AKSA", "AKSEN"])
        #expect(results.map(\.name) == ["Aksa Akrilik Kimya Sanayii A.S.", "AKSA ENERJI"])
        let url = try #require(client.requestedURLs.first)
        #expect(url.path == "/v1/finance/search")
        #expect(url.query?.contains("q=aks") == true)
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
#endif
