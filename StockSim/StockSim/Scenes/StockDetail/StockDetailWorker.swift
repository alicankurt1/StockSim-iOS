import Domain

protocol StockDetailWorking: Sendable {
    func fetchQuote(for symbol: Symbol) async throws -> Quote?
    func fetchHistory(for symbol: Symbol, range: ChartRange) async throws -> [Candle]
    func liveUpdates(for symbol: Symbol) async -> AsyncStream<MarketUpdate>
    func portfolioChanges() async -> AsyncStream<Portfolio>
}

struct StockDetailWorker: StockDetailWorking {

    let market: any MarketDataProviding
    let portfolio: any PortfolioStoring

    func portfolioChanges() async -> AsyncStream<Portfolio> {
        await portfolio.changes()
    }

    func fetchQuote(for symbol: Symbol) async throws -> Quote? {
        try await market.quotes(for: [symbol]).first
    }

    func fetchHistory(for symbol: Symbol, range: ChartRange) async throws -> [Candle] {
        try await market.history(for: symbol, range: range)
    }

    func liveUpdates(for symbol: Symbol) async -> AsyncStream<MarketUpdate> {
        await market.updates(for: [symbol])
    }
}
