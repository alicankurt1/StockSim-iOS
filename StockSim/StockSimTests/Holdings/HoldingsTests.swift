import Foundation
import Testing
import UIKit
import Domain
@testable import StockSim

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let asels = Instrument(symbol: Symbol("ASELS"), name: "Aselsan")
private let date = Date(timeIntervalSince1970: 1_800_000_000)   // 15 Oca 2027, 11:00 İstanbul

private func quote(_ instrument: Instrument, _ price: Decimal) -> Quote {
    Quote(symbol: instrument.symbol, price: Money(price), previousClose: Money(price), timestamp: date)
}

/// 1.000 ₺ nakit; 4 THYAO @100 alındı, 1'i @120 satıldı.
private func samplePortfolio() throws -> Portfolio {
    var portfolio = Portfolio(cash: Money(1_000))
    try portfolio.execute(Order(symbol: thyao.symbol, side: .buy, quantity: 4), at: quote(thyao, 100))
    try portfolio.execute(Order(symbol: thyao.symbol, side: .sell, quantity: 1), at: quote(thyao, 120))
    return portfolio
}

// MARK: - Presenter

@MainActor
private final class DisplaySpy: HoldingsDisplayLogic {
    private(set) var viewModels: [Holdings.Load.ViewModel] = []
    func displayHoldings(viewModel: Holdings.Load.ViewModel) { viewModels.append(viewModel) }
}

@MainActor
struct HoldingsPresenterTests {

    private func present(_ portfolio: Portfolio, prices: [Instrument: Decimal]) -> Holdings.Load.ViewModel? {
        let presenter = HoldingsPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        let quotes = Dictionary(uniqueKeysWithValues: prices.map { ($0.key.symbol, quote($0.key, $0.value)) })
        presenter.presentHoldings(response: .init(portfolio: portfolio, quotes: quotes, names: [:]))
        return display.viewModels.first
    }

    /// Nakit 1.000 − 400 + 120 = 720; 3 THYAO @130 = 390; toplam 1.110 → +110 (+%11).
    @Test func accountCardTotals() throws {
        let card = try #require(present(try samplePortfolio(), prices: [thyao: 130])).account

        #expect(card.totalValue == "₺1.110,00")
        #expect(card.totalProfitLoss == "+₺110,00 (+%11,00)")
        #expect(card.trend == .up)
        #expect(card.cash == "₺720,00")
        #expect(card.invested == "₺390,00")
    }

    /// 3 adet ort. 100, fiyat 130 → değer 390, K/Z +90 (+%30).
    @Test func positionRowShowsValueAndProfit() throws {
        let rows = try #require(present(try samplePortfolio(), prices: [thyao: 130])).positions

        #expect(rows.count == 1)
        #expect(rows.first?.summary == "3 × ₺100,00")
        #expect(rows.first?.value == "₺390,00")
        #expect(rows.first?.profitLoss == "+₺90,00 (+%30,00)")
    }

    /// En yeni işlem üstte; alım nakdi azaltır (-), satış artırır (+).
    @Test func activityIsNewestFirstWithCashFlowSigns() throws {
        let activity = try #require(present(try samplePortfolio(), prices: [:])).activity

        #expect(activity.map(\.title) == ["Sold 1 THYAO", "Bought 4 THYAO"])
        #expect(activity.map(\.amount) == ["+₺120,00", "-₺400,00"])
        #expect(activity.first?.subtitle == "15 Jan, 11:00 · ₺120,00")
    }

    @Test func emptyAccount() throws {
        let viewModel = try #require(present(Portfolio(cash: Money(100_000)), prices: [:]))

        #expect(viewModel.positions.isEmpty)
        #expect(viewModel.activity.isEmpty)
        #expect(viewModel.account.totalValue == "₺100.000,00")
        #expect(viewModel.account.totalProfitLoss == "₺0,00 (%0,00)")
    }
}

// MARK: - Interactor

@MainActor
private final class WorkerFake: HoldingsWorking {
    var portfolio: Portfolio
    var marketUpdates: [MarketUpdate] = []
    var portfolioUpdates: [Portfolio] = []
    private(set) var resetCount = 0

    init(portfolio: Portfolio) { self.portfolio = portfolio }

    func fetchInstruments() async throws -> [Instrument] { [thyao, asels] }
    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote] { [quote(thyao, 110), quote(asels, 50)] }
    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> { finite(marketUpdates) }
    func currentPortfolio() async -> Portfolio { portfolio }
    func portfolioChanges() async -> AsyncStream<Portfolio> { finite(portfolioUpdates) }
    func resetPortfolio() async { resetCount += 1 }

    private func finite<T: Sendable>(_ values: [T]) -> AsyncStream<T> {
        AsyncStream { continuation in
            values.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

@MainActor
private final class PresenterSpy: HoldingsPresentationLogic {
    private(set) var responses: [Holdings.Load.Response] = []
    func presentHoldings(response: Holdings.Load.Response) { responses.append(response) }
}

@MainActor
struct HoldingsInteractorTests {

    @Test func loadPresentsPortfolioWithQuotesAndNames() async throws {
        let presenter = PresenterSpy()
        let interactor = HoldingsInteractor(presenter: presenter, worker: WorkerFake(portfolio: try samplePortfolio()))

        await interactor.load()

        let response = try #require(presenter.responses.first)
        #expect(response.quotes[thyao.symbol]?.price == Money(110))
        #expect(response.names[thyao.symbol] == "Türk Hava Yolları")
        #expect(interactor.instrument(for: thyao.symbol) == thyao)
    }

    /// Sadece elde tutulan hissenin fiyatı ekranı yeniler; ASELS'in fiyatı değişse de yenilemez.
    @Test func onlyHeldSymbolsTriggerRefresh() async throws {
        let worker = WorkerFake(portfolio: try samplePortfolio())
        worker.marketUpdates = [.quote(quote(asels, 51)), .quote(quote(thyao, 140))]
        let presenter = PresenterSpy()
        let interactor = HoldingsInteractor(presenter: presenter, worker: worker)
        await interactor.load()

        await interactor.startLiveUpdates()

        #expect(presenter.responses.count == 2)   // yükleme + THYAO
        #expect(presenter.responses.last?.quotes[thyao.symbol]?.price == Money(140))
    }

    @Test func portfolioChangesRefresh() async throws {
        let worker = WorkerFake(portfolio: Portfolio(cash: Money(1_000)))
        worker.portfolioUpdates = [try samplePortfolio()]
        let presenter = PresenterSpy()
        let interactor = HoldingsInteractor(presenter: presenter, worker: worker)
        await interactor.load()

        await interactor.startLiveUpdates()

        #expect(presenter.responses.last?.portfolio.trades.count == 2)
    }

    @Test func resetAsksTheStore() async {
        let worker = WorkerFake(portfolio: Portfolio(cash: Money(1_000)))
        let interactor = HoldingsInteractor(presenter: PresenterSpy(), worker: worker)

        await interactor.resetAccount()

        #expect(worker.resetCount == 1)
    }
}

// MARK: - Router

@MainActor
private final class DetailStoreSpy: StockDetailDataStore {
    var instrument: Instrument?
    var initialQuote: Quote?
}

@MainActor
private struct HoldingsStoreStub: HoldingsDataStore {
    func instrument(for symbol: Symbol) -> Instrument? { symbol == thyao.symbol ? thyao : nil }
    func quote(for symbol: Symbol) -> Quote? { symbol == thyao.symbol ? StockSimTests.quote(thyao, 110) : nil }
}

@MainActor
struct HoldingsRouterTests {

    @Test func routePassesInstrumentAndQuoteAndPushes() {
        let destination = DetailStoreSpy()
        let router = HoldingsRouter(dataStore: HoldingsStoreStub()) { (UIViewController(), destination) }
        let source = UIViewController()
        let navigationController = UINavigationController(rootViewController: source)
        router.viewController = source

        router.routeToStockDetail(symbol: thyao.symbol)

        #expect(destination.instrument == thyao)
        #expect(destination.initialQuote?.price == Money(110))
        #expect(navigationController.viewControllers.count == 2)
    }
}
