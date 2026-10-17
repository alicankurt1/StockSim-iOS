import Foundation
import Domain

/// Gerçek BIST verisi (Yahoo Finance, ~15 dk gecikmeli).
///
/// LSP: `MarketSimulator` ile aynı sözleşmeyi (`MarketDataProviding`) uygular; ekranlar
/// hangisinin bağlı olduğunu bilmez. Farklar sözleşmenin içinde kalır:
/// - Canlı akış "push" değil "poll": belirli aralıklarla fiyat sorulur.
/// - Ağ koparsa `feedInterrupted`, geri gelince `feedRestored` yayınlanır.
/// - İşlem durdurma (halt) bilgisi bu kaynakta yok.
///
/// Not: Resmî olmayan bir uç nokta; geliştirme ve demo içindir. Kaynak protokolün arkasında
/// olduğu için lisanslı bir sağlayıcı ileride bu tipin yerine yazılabilir.
public actor YahooMarketProvider: MarketDataProviding {

    private let client: HTTPClient
    private let catalog: [Instrument]
    private let pollInterval: Duration
    private let cacheLifetime: TimeInterval
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: @Sendable () -> Date

    /// Geçmiş veri önbelleği: grafik aralığı değiştirip geri gelince aynı isteği tekrar atmayalım.
    private var historyCache: [String: (candles: [Candle], fetchedAt: Date)] = [:]

    public init(
        client: HTTPClient = URLSessionHTTPClient(),
        instruments: [Instrument] = BistCatalog.instruments,
        pollInterval: Duration = .seconds(30),
        cacheLifetime: TimeInterval = 5 * 60,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.catalog = instruments
        self.pollInterval = pollInterval
        self.cacheLifetime = cacheLifetime
        self.sleep = sleep
        self.now = now
    }

    // MARK: - MarketDataProviding

    public func instruments() -> [Instrument] {
        catalog
    }

    /// Hisseler paralel istenir (TaskGroup). Birinin hatası diğerlerini engellemez;
    /// hiçbiri gelmezse hata fırlatılır.
    public func quotes(for symbols: [Symbol]) async throws -> [Quote] {
        let client = client
        let results = await withTaskGroup(of: (Int, Quote?).self) { group in
            for (index, symbol) in symbols.enumerated() {
                group.addTask {
                    let result = try? await Self.fetchChart(client: client, symbol: symbol, range: "1d", interval: "1d")
                    return (index, try? result?.quote(for: symbol))
                }
            }
            var collected: [(Int, Quote?)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        // Sonuçlar karışık sırayla gelir; istenen sıraya geri diz.
        let quotes = results.sorted { $0.0 < $1.0 }.compactMap(\.1)
        if quotes.isEmpty, !symbols.isEmpty {
            throw MarketDataError.unavailable("No quotes")
        }
        return quotes
    }

    public func history(for symbol: Symbol, range: ChartRange) async throws -> [Candle] {
        let key = "\(symbol.rawValue)-\(range.rawValue)"
        if let cached = historyCache[key], now().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached.candles
        }
        let request = Self.request(for: range)
        let result = try await Self.fetchChart(client: client, symbol: symbol, range: request.range, interval: request.interval)
        let candles = result.candles()
        historyCache[key] = (candles, now())
        return candles
    }

    /// Belirli aralıklarla fiyat soran bir akış. Dinleyen bırakınca (Task iptali) döngü durur.
    public func updates(for symbols: [Symbol]) -> AsyncStream<MarketUpdate> {
        let (stream, continuation) = AsyncStream.makeStream(of: MarketUpdate.self, bufferingPolicy: .bufferingNewest(64))
        let poller = Task { [weak self] in
            var isInterrupted = false
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let quotes = try await self.quotes(for: symbols)
                    if isInterrupted {
                        isInterrupted = false
                        continuation.yield(.feedRestored)
                    }
                    quotes.forEach { continuation.yield(.quote($0)) }
                } catch {
                    if !isInterrupted {
                        isInterrupted = true
                        continuation.yield(.feedInterrupted)
                    }
                }
                do { try await self.sleep(self.pollInterval) } catch { break }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in poller.cancel() }
        return stream
    }

    // MARK: - İstek

    /// Grafik aralığı → Yahoo parametreleri.
    static func request(for range: ChartRange) -> (range: String, interval: String) {
        switch range {
        case .day: ("1d", "5m")
        case .week: ("5d", "60m")
        case .month: ("1mo", "1d")
        case .year: ("1y", "1wk")
        }
    }

    /// BIST hisseleri Yahoo'da ".IS" ekiyle (İstanbul) geçer: THYAO → THYAO.IS.
    static func url(for symbol: Symbol, range: String, interval: String) -> URL {
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol.rawValue).IS")!
        components.queryItems = [URLQueryItem(name: "range", value: range), URLQueryItem(name: "interval", value: interval)]
        return components.url!
    }

    /// `static` ve actor dışında: paralel istekler actor'ü sırada bekletmesin.
    private static func fetchChart(client: HTTPClient, symbol: Symbol, range: String, interval: String) async throws -> YahooChartResponse.Result {
        var request = URLRequest(url: url(for: symbol, range: range, interval: interval))
        // Varsayılan kullanıcı ajanı bazen reddediliyor.
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await client.data(for: request)
        let decoded = try? JSONDecoder().decode(YahooChartResponse.self, from: data)

        if response.statusCode == 404 || decoded?.chart.error?.code == "Not Found" {
            throw MarketDataError.unknownSymbol(symbol)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw MarketDataError.unavailable("HTTP \(response.statusCode)")
        }
        guard let result = decoded?.chart.result?.first else {
            throw MarketDataError.unavailable(decoded?.chart.error?.description ?? "Unexpected response")
        }
        return result
    }
}
