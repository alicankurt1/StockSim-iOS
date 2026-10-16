import Domain

/// Worker: Interactor'ın dış dünyayla (veri kaynağı, ağ, disk) konuşan yardımcısı.
/// Interactor bu protokolü bilir; testte yerine sahtesi verilir.
protocol WatchlistWorking: Sendable {
    func fetchInstruments() async throws -> [Instrument]
    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote]
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
}
