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

    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote] {
        try await base.fetchQuotes(for: symbols)
    }

    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> {
        await base.liveUpdates(for: symbols)
    }
}
