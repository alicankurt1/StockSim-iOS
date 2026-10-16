import Foundation
import Testing
import Domain
@testable import StockSim

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")

private func makeQuote(_ price: Decimal) -> Quote {
    Quote(symbol: thyao.symbol, price: Money(price), previousClose: Money(price), timestamp: Date(timeIntervalSince1970: 0))
}

/// Gerçek kuralları kullanan sahte worker: içinde gerçek bir `Portfolio` var.
@MainActor
private final class WorkerFake: TradeTicketWorking {
    var portfolio: Portfolio
    var quote: Quote? = makeQuote(100)
    var updates: [MarketUpdate] = []
    private(set) var executedOrders: [Order] = []

    init(cash: Decimal = 1_000) {
        portfolio = Portfolio(cash: Money(cash))
    }

    func fetchQuote(for symbol: Symbol) async throws -> Quote? { quote }

    func liveUpdates(for symbol: Symbol) async -> AsyncStream<MarketUpdate> {
        let updates = updates
        return AsyncStream { continuation in
            for update in updates { continuation.yield(update) }
            continuation.finish()
        }
    }

    func currentPortfolio() async -> Portfolio { portfolio }

    func execute(_ order: Order, at quote: Quote) async throws -> Trade {
        executedOrders.append(order)
        return try portfolio.execute(order, at: quote)
    }
}

@MainActor
private final class PresenterSpy: TradeTicketPresentationLogic {
    private(set) var forms: [TradeTicket.FormResponse] = []
    private(set) var completedTrades: [Trade] = []

    func presentForm(response: TradeTicket.FormResponse) { forms.append(response) }
    func presentTradeCompleted(response: TradeTicket.Submit.Response) { completedTrades.append(response.trade) }
}

@MainActor
struct TradeTicketInteractorTests {

    private func makeInteractor(_ worker: WorkerFake, side: OrderSide = .buy) -> (TradeTicketInteractor, PresenterSpy) {
        let presenter = PresenterSpy()
        let interactor = TradeTicketInteractor(presenter: presenter, worker: worker)
        interactor.instrument = thyao
        interactor.side = side
        return (interactor, presenter)
    }

    @Test func loadPresentsFormWithCashAndQuote() async {
        let (interactor, presenter) = makeInteractor(WorkerFake(cash: 1_000))

        await interactor.load(request: .init())

        let form = presenter.forms.last
        #expect(form?.cash == Money(1_000))
        #expect(form?.quote == makeQuote(100))
        #expect(form?.quantity == 1)
        #expect(form?.error == nil)
    }

    /// Doğrulama Domain kurallarını kullanır: 11 × 100 = 1.100 > 1.000 nakit.
    @Test func editingQuantityRevalidates() async {
        let (interactor, presenter) = makeInteractor(WorkerFake(cash: 1_000))
        await interactor.load(request: .init())

        interactor.edit(request: .init(quantity: 11))

        #expect(presenter.forms.last?.error == .insufficientCash(available: Money(1_000), required: Money(1_100)))
    }

    @Test func sellingWithoutSharesIsRejected() async {
        let (interactor, presenter) = makeInteractor(WorkerFake(), side: .sell)
        await interactor.load(request: .init())

        #expect(presenter.forms.last?.error == .insufficientQuantity(available: 0, requested: 1))
    }

    @Test func zeroQuantityIsInvalid() async {
        let (interactor, presenter) = makeInteractor(WorkerFake())
        await interactor.load(request: .init())

        interactor.edit(request: .init(quantity: 0))

        #expect(presenter.forms.last?.error == .invalidQuantity)
    }

    /// Canlı akış: fiyat güncellenir; işlem durdurulunca form kilitlenir, devam edince açılır.
    @Test func liveUpdatesTrackPriceAndHalts() async {
        let worker = WorkerFake()
        worker.updates = [.quote(makeQuote(120)), .halted(thyao.symbol)]
        let (interactor, presenter) = makeInteractor(worker)
        await interactor.load(request: .init())

        await interactor.startLiveUpdates()

        #expect(presenter.forms.last?.quote == makeQuote(120))
        #expect(presenter.forms.last?.error == .marketHalted(thyao.symbol))
    }

    @Test func submitExecutesOrderAndPresentsTrade() async {
        let worker = WorkerFake(cash: 1_000)
        let (interactor, presenter) = makeInteractor(worker)
        await interactor.load(request: .init())
        interactor.edit(request: .init(quantity: 3))

        await interactor.submit(request: .init())

        #expect(worker.executedOrders.map(\.quantity) == [3])
        #expect(presenter.completedTrades.first?.quantity == 3)
        #expect(worker.portfolio.cash == Money(700))
    }

    /// Kural ihlali varken emir worker'a hiç gitmez.
    @Test func invalidSubmitDoesNotReachTheStore() async {
        let worker = WorkerFake(cash: 50)
        let (interactor, presenter) = makeInteractor(worker)
        await interactor.load(request: .init())

        await interactor.submit(request: .init())

        #expect(worker.executedOrders.isEmpty)
        #expect(presenter.completedTrades.isEmpty)
        #expect(presenter.forms.last?.error == .insufficientCash(available: Money(50), required: Money(100)))
    }
}
