import Domain

/// Worker: Interactor'ın dış dünyayla (veri kaynağı, ağ, disk) konuşan yardımcısı.
/// Interactor bu protokolü bilir; testte yerine sahtesi verilir.
protocol WatchlistWorking: Sendable {
    func fetchInstruments() async throws -> [Instrument]
}

struct WatchlistWorker: WatchlistWorking {

    /// Simülatör mü gerçek veri mi, Worker bilmez (DIP).
    let market: any MarketDataProviding

    func fetchInstruments() async throws -> [Instrument] {
        try await market.instruments()
    }
}
