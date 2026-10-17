import Domain

protocol HoldingsWorking: Sendable {
    func fetchInstruments() async throws -> [Instrument]
    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote]
    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate>
    func currentPortfolio() async -> Portfolio
    func portfolioChanges() async -> AsyncStream<Portfolio>
    func resetPortfolio() async
}

struct HoldingsWorker: HoldingsWorking {

    let market: any MarketDataProviding
    let portfolio: any PortfolioStoring

    func fetchInstruments() async throws -> [Instrument] {
        try await market.instruments()
    }

    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote] {
        try await market.quotes(for: symbols)
    }

    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> {
        await market.updates(for: symbols)
    }

    func currentPortfolio() async -> Portfolio {
        await portfolio.currentPortfolio()
    }

    func portfolioChanges() async -> AsyncStream<Portfolio> {
        await portfolio.changes()
    }

    func resetPortfolio() async {
        await portfolio.reset()
    }
}
