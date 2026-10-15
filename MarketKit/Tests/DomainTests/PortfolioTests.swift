import Foundation
import Testing
@testable import Domain

struct PortfolioTests {

    private let thyao = Symbol("THYAO")
    private let asels = Symbol("ASELS")

    private func quote(_ symbol: Symbol, _ price: String) -> Quote {
        Quote(symbol: symbol, price: money(price), previousClose: money(price), timestamp: Date(timeIntervalSince1970: 0))
    }

    private func buy(_ symbol: Symbol, _ quantity: Int) -> Order {
        Order(symbol: symbol, side: .buy, quantity: quantity)
    }

    private func sell(_ symbol: Symbol, _ quantity: Int) -> Order {
        Order(symbol: symbol, side: .sell, quantity: quantity)
    }

    // MARK: - Alım / satım

    @Test func buyMovesCashIntoPosition() throws {
        var portfolio = Portfolio(cash: money("100000"))
        let trade = try portfolio.execute(buy(thyao, 10), at: quote(thyao, "287.50"))

        #expect(portfolio.cash == money("97125"))
        #expect(portfolio.positions[thyao]?.quantity == 10)
        #expect(trade.total == money("2875"))
        #expect(portfolio.trades == [trade])
    }

    @Test func sellMovesPositionBackIntoCash() throws {
        var portfolio = Portfolio(cash: money("10000"))
        try portfolio.execute(buy(thyao, 10), at: quote(thyao, "100"))
        try portfolio.execute(sell(thyao, 4), at: quote(thyao, "130"))

        #expect(portfolio.cash == money("9520"))    // 10000 - 1000 + 520
        #expect(portfolio.positions[thyao]?.quantity == 6)
        #expect(portfolio.realizedPnL == money("120"))
        #expect(portfolio.trades.map(\.side) == [.buy, .sell])
    }

    @Test func soldOutPositionIsNotOpenButKeepsRealizedPnL() throws {
        var portfolio = Portfolio(cash: money("1000"))
        try portfolio.execute(buy(thyao, 10), at: quote(thyao, "100"))
        try portfolio.execute(sell(thyao, 10), at: quote(thyao, "90"))

        #expect(portfolio.openPositions.isEmpty)
        #expect(portfolio.realizedPnL == money("-100"))
    }

    // MARK: - Bakiye ve adet kontrolleri

    /// Nakit yetmezse hata; tam tutarında nakit varsa alım yapılabilir.
    @Test(arguments: [
        ("1000", 10, true),     // tam tutar
        ("999.99", 10, false),  // 1 kuruş eksik
    ])
    func buyChecksCash(cash: String, quantity: Int, succeeds: Bool) throws {
        var portfolio = Portfolio(cash: money(cash))
        let order = buy(thyao, quantity)

        if succeeds {
            try portfolio.execute(order, at: quote(thyao, "100"))
            #expect(portfolio.cash == .zero)
        } else {
            #expect(throws: TradingError.insufficientCash(available: money(cash), required: money("1000"))) {
                try portfolio.execute(order, at: quote(thyao, "100"))
            }
        }
    }

    /// Hata olursa portföyün hiçbir alanı değişmemeli.
    @Test(arguments: [
        (OrderSide.buy, 1000, TradingError.insufficientCash(available: money("5000"), required: money("100000"))),
        (OrderSide.sell, 11, TradingError.insufficientQuantity(available: 10, requested: 11)),
        (OrderSide.buy, 0, TradingError.invalidQuantity),
    ])
    func failedOrderLeavesPortfolioUnchanged(side: OrderSide, quantity: Int, error: TradingError) throws {
        var portfolio = Portfolio(cash: money("6000"))
        try portfolio.execute(buy(thyao, 10), at: quote(thyao, "100"))
        let before = portfolio

        #expect(throws: error) {
            try portfolio.execute(Order(symbol: thyao, side: side, quantity: quantity), at: quote(thyao, "100"))
        }
        #expect(portfolio == before)
    }

    // MARK: - Değerleme

    @Test func valuationUsesCurrentPrices() throws {
        var portfolio = Portfolio(cash: money("10000"))
        try portfolio.execute(buy(thyao, 10), at: quote(thyao, "100"))   // 1000
        try portfolio.execute(buy(asels, 20), at: quote(asels, "50"))    // 1000
        let prices = [thyao: money("120"), asels: money("45")]

        #expect(portfolio.positionsValue(prices: prices) == money("2100"))   // 1200 + 900
        #expect(portfolio.totalValue(prices: prices) == money("10100"))      // 8000 nakit + 2100
        #expect(portfolio.unrealizedPnL(prices: prices) == money("100"))     // +200 - 100
    }

    @Test func missingPriceFallsBackToCost() throws {
        var portfolio = Portfolio(cash: money("1000"))
        try portfolio.execute(buy(thyao, 5), at: quote(thyao, "100"))

        #expect(portfolio.positionsValue(prices: [:]) == money("500"))
        #expect(portfolio.unrealizedPnL(prices: [:]) == .zero)
    }

    @Test func openPositionsAreSortedBySymbol() throws {
        var portfolio = Portfolio(cash: money("10000"))
        try portfolio.execute(buy(thyao, 1), at: quote(thyao, "100"))
        try portfolio.execute(buy(asels, 1), at: quote(asels, "100"))

        #expect(portfolio.openPositions.map(\.symbol) == [asels, thyao])
    }
}

// MARK: - OCP: yeni emir tipi Portfolio'yu değiştirmeden eklenebilir

/// Sadece testte var olan bir limit alım emri: fiyat limitin altındaysa gerçekleşir.
/// Portfolio'da tek satır değiştirmeden çalışması OCP'nin kanıtı.
private struct TestLimitOrder: OrderType {
    let limit: Money

    func executionPrice(for side: OrderSide, quote: Quote) -> Money? {
        quote.price <= limit ? quote.price : nil
    }
}

struct OrderTypeTests {

    private let thyao = Symbol("THYAO")

    private func quote(_ price: String) -> Quote {
        Quote(symbol: thyao, price: money(price), previousClose: money(price), timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test func marketOrderFillsAtQuotePrice() {
        #expect(MarketOrder().executionPrice(for: .buy, quote: quote("287.50")) == money("287.50"))
    }

    @Test func newOrderTypeWorksWithoutChangingPortfolio() throws {
        var portfolio = Portfolio(cash: money("1000"))
        let order = Order(symbol: thyao, side: .buy, quantity: 1, type: TestLimitOrder(limit: money("100")))

        #expect(throws: TradingError.orderNotFillable) {
            try portfolio.execute(order, at: quote("101"))
        }
        let trade = try portfolio.execute(order, at: quote("99"))
        #expect(trade.price == money("99"))
    }
}
