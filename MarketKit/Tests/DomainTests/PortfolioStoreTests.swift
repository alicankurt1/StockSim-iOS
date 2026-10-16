import Foundation
import Testing
@testable import Domain

struct PortfolioStoreTests {

    private let thyao = Symbol("THYAO")

    private func quote(_ price: Decimal) -> Quote {
        Quote(symbol: thyao, price: Money(price), previousClose: Money(price), timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test func startsWithInitialCash() async {
        let store = PortfolioStore(initialCash: Money(100_000))
        #expect(await store.currentPortfolio().cash == Money(100_000))
    }

    @Test func executeUpdatesTheSharedPortfolio() async throws {
        let store = PortfolioStore(initialCash: Money(1_000))

        let trade = try await store.execute(Order(symbol: thyao, side: .buy, quantity: 3), at: quote(100))

        let portfolio = await store.currentPortfolio()
        #expect(portfolio.cash == Money(700))
        #expect(portfolio.positions[thyao]?.quantity == 3)
        #expect(portfolio.trades == [trade])
    }

    @Test func failedOrderLeavesStoreUnchanged() async {
        let store = PortfolioStore(initialCash: Money(100))
        let before = await store.currentPortfolio()

        await #expect(throws: TradingError.insufficientCash(available: Money(100), required: Money(200))) {
            try await store.execute(Order(symbol: self.thyao, side: .buy, quantity: 2), at: self.quote(100))
        }
        #expect(await store.currentPortfolio() == before)
    }

    /// Actor'ün varlık sebebi: 100 alım emri AYNI ANDA gelir, nakit sadece 50'sine yeter.
    /// Erişimler sıraya konduğu için tam 50'si başarılı olur, nakit asla eksiye düşmez.
    @Test func concurrentOrdersNeverSpendCashTwice() async {
        let store = PortfolioStore(initialCash: Money(500))
        let order = Order(symbol: thyao, side: .buy, quantity: 1)
        let price = quote(10)

        let successes = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask { (try? await store.execute(order, at: price)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }

        let portfolio = await store.currentPortfolio()
        #expect(successes == 50)
        #expect(portfolio.cash == .zero)
        #expect(portfolio.positions[thyao]?.quantity == 50)
    }

    /// Abone önce güncel hali, sonra her başarılı emirden sonra yeni hali alır.
    @Test func changesStreamsCurrentThenEachExecution() async throws {
        let store = PortfolioStore(initialCash: Money(1_000))
        var iterator = await store.changes().makeAsyncIterator()

        #expect(await iterator.next()?.cash == Money(1_000))

        try await store.execute(Order(symbol: thyao, side: .buy, quantity: 2), at: quote(100))
        #expect(await iterator.next()?.positions[thyao]?.quantity == 2)
    }
}
