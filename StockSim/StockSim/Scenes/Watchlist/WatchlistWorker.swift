import Domain

/// Worker: Interactor'ın dış dünyayla (veri kaynağı, ağ, disk) konuşan yardımcısı.
/// Interactor bu protokolü bilir; testte yerine sahtesi verilir.
protocol WatchlistWorking: Sendable {
    func fetchInstruments() async throws -> [Instrument]
    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote]
    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate>
    /// Her hissenin gün içi kapanışları. Geçmişi alınamayan hisse sonuçta olmaz.
    func fetchIntradayCloses(for symbols: [Symbol]) async -> [Symbol: [Money]]
}

struct WatchlistWorker: WatchlistWorking {

    /// Simülatör mü gerçek veri mi, Worker bilmez (DIP).
    let market: any MarketDataProviding

    func fetchInstruments() async throws -> [Instrument] {
        try await market.instruments()
    }

    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote] {
        try await market.quotes(for: symbols)
    }

    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> {
        await market.updates(for: symbols)
    }

    /// Hisseler paralel istenir: gerçek veride her biri bir ağ isteği; sırayla 10 istek yavaş olurdu.
    func fetchIntradayCloses(for symbols: [Symbol]) async -> [Symbol: [Money]] {
        let market = market
        return await withTaskGroup(of: (Symbol, [Money]?).self) { group in
            for symbol in symbols {
                group.addTask {
                    // Bir hissenin geçmişi gelmezse liste yine açılsın; o kartta sparkline olmaz.
                    let candles = try? await market.history(for: symbol, range: .day)
                    return (symbol, candles?.map(\.close))
                }
            }
            var result: [Symbol: [Money]] = [:]
            for await (symbol, closes) in group {
                if let closes { result[symbol] = closes }
            }
            return result
        }
    }
}
