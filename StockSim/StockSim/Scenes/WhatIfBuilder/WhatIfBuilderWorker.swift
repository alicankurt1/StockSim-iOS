import Domain

protocol WhatIfBuilderWorking: Sendable {
    func instruments() async -> [Instrument]
    func history(for symbol: Symbol, range: ChartRange) async throws -> [Candle]
    func quote(for symbol: Symbol) async throws -> Quote?
    func track(_ scenario: WhatIfScenario) async
    func update(_ scenario: WhatIfScenario) async
}

struct WhatIfBuilderWorker: WhatIfBuilderWorking {

    let market: any MarketDataProviding
    let watchlist: any WatchlistStoring
    let store: any WhatIfStoring

    /// Seçilebilecek hisseler: kullanıcının izleme listesi.
    func instruments() async -> [Instrument] {
        await watchlist.current()
    }

    func history(for symbol: Symbol, range: ChartRange) async throws -> [Candle] {
        try await market.history(for: symbol, range: range)
    }

    func quote(for symbol: Symbol) async throws -> Quote? {
        try await market.quotes(for: [symbol]).first
    }

    func track(_ scenario: WhatIfScenario) async {
        await store.add(scenario)
    }

    func update(_ scenario: WhatIfScenario) async {
        await store.update(scenario)
    }
}
