import Domain

/// Decorator: başka bir Worker'ı sarar ve her isteği geciktirir.
///
/// Simülatör anında cevap verdiği için skeleton görünmez. Bu sarmalayıcıyla yavaş bir
/// ağı taklit ediyoruz. Ne `WatchlistWorker` ne de Interactor değişti: davranışı
/// sarmalayarak genişlettik (OCP).
///
/// Açmak için: Xcode → Product → Scheme → Edit Scheme → Run → Arguments → `-slowLoading`
struct DelayedWatchlistWorker: WatchlistWorking {

    let base: WatchlistWorking
    let delay: Duration

    func fetchInstruments() async throws -> [Instrument] {
        try await Task.sleep(for: delay)
        return try await base.fetchInstruments()
    }

    func watchlistChanges() async -> AsyncStream<[Instrument]> {
        await base.watchlistChanges()
    }

    func removeFromWatchlist(_ symbol: Symbol) async {
        await base.removeFromWatchlist(symbol)
    }

    func reorderWatchlist(_ symbols: [Symbol]) async {
        await base.reorderWatchlist(symbols)
    }

    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote] {
        try await base.fetchQuotes(for: symbols)
    }

    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> {
        await base.liveUpdates(for: symbols)
    }

    func fetchIntradayCloses(for symbols: [Symbol]) async -> [Symbol: [Money]] {
        await base.fetchIntradayCloses(for: symbols)
    }
}
