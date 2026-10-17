import Domain

protocol StockSearchWorking: Sendable {
    func search(_ query: String) async throws -> [Instrument]
    func suggestions() async -> [Instrument]
    func watchlistSymbols() async -> Set<Symbol>
    func add(_ instrument: Instrument) async
}

struct StockSearchWorker: StockSearchWorking {

    /// Simülatörde çevrimdışı rehber, gerçek veride Yahoo araması (ikisi de aynı protokol).
    let searcher: any SymbolSearching
    let watchlist: any WatchlistStoring

    func search(_ query: String) async throws -> [Instrument] {
        try await searcher.searchInstruments(matching: query)
    }

    /// Arama kutusu boşken gösterilen öneriler: listede olmayan rehber hisseleri.
    func suggestions() async -> [Instrument] {
        let current = Set(await watchlist.current().map(\.symbol))
        return BistDirectory.instruments.filter { !current.contains($0.symbol) }
    }

    func watchlistSymbols() async -> Set<Symbol> {
        Set(await watchlist.current().map(\.symbol))
    }

    func add(_ instrument: Instrument) async {
        await watchlist.add(instrument)
    }
}
