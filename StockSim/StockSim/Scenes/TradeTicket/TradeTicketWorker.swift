import Domain

/// Al/sat için gereken iki dış kaynak: piyasa (fiyat, durdurma) ve hesap (nakit, pozisyon).
protocol TradeTicketWorking: Sendable {
    func fetchQuote(for symbol: Symbol) async throws -> Quote?
    func liveUpdates(for symbol: Symbol) async -> AsyncStream<MarketUpdate>
    func currentPortfolio() async -> Portfolio
    func execute(_ order: Order, at quote: Quote) async throws -> Trade
}

struct TradeTicketWorker: TradeTicketWorking {

    let market: any MarketDataProviding
    let portfolio: any PortfolioStoring

    func fetchQuote(for symbol: Symbol) async throws -> Quote? {
        try await market.quotes(for: [symbol]).first
    }

    func liveUpdates(for symbol: Symbol) async -> AsyncStream<MarketUpdate> {
        await market.updates(for: [symbol])
    }

    func currentPortfolio() async -> Portfolio {
        await portfolio.currentPortfolio()
    }

    func execute(_ order: Order, at quote: Quote) async throws -> Trade {
        try await portfolio.execute(order, at: quote)
    }
}
