import Foundation
import Testing
import Domain
@testable import StockSim

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let date = Date(timeIntervalSince1970: 0)

private func makeQuote(_ price: Decimal, previousClose: Decimal = 100) -> Quote {
    Quote(symbol: thyao.symbol, price: Money(price), previousClose: Money(previousClose), timestamp: date)
}

private func candle(open: Decimal, high: Decimal, low: Decimal, close: Decimal) -> Candle {
    Candle(date: date, open: Money(open), high: Money(high), low: Money(low), close: Money(close))
}

private struct SomeError: Error {}

private struct WorkerStub: StockDetailWorking {
    var quote: Quote? = makeQuote(101)
    var candlesByRange: [ChartRange: [Candle]] = [:]
    var fails = false
    var updates: [MarketUpdate] = []
    var portfolios: [Portfolio] = []

    func portfolioChanges() async -> AsyncStream<Portfolio> {
        let portfolios = portfolios
        return AsyncStream { continuation in
            for portfolio in portfolios { continuation.yield(portfolio) }
            continuation.finish()
        }
    }

    func fetchQuote(for symbol: Symbol) async throws -> Quote? {
        if fails { throw SomeError() }
        return quote
    }

    func fetchHistory(for symbol: Symbol, range: ChartRange) async throws -> [Candle] {
        if fails { throw SomeError() }
        return candlesByRange[range] ?? []
    }

    func liveUpdates(for symbol: Symbol) async -> AsyncStream<MarketUpdate> {
        AsyncStream { continuation in
            for update in updates { continuation.yield(update) }
            continuation.finish()
        }
    }
}

@MainActor
private final class PresenterSpy: StockDetailPresentationLogic {
    private(set) var details: [StockDetail.Load.Response] = []
    private(set) var updates: [StockDetail.Update.Response] = []
    private(set) var errorCount = 0

    func presentDetail(response: StockDetail.Load.Response) { details.append(response) }
    func presentQuoteUpdate(response: StockDetail.Update.Response) { updates.append(response) }
    func presentLoadError() { errorCount += 1 }

    private(set) var selections: [StockDetail.Select.Response] = []
    func presentSelection(response: StockDetail.Select.Response) { selections.append(response) }

    private(set) var initials: [StockDetail.Initial.Response] = []
    func presentInitial(response: StockDetail.Initial.Response) { initials.append(response) }

    private(set) var holdings: [StockDetail.Holding.Response] = []
    func presentHolding(response: StockDetail.Holding.Response) { holdings.append(response) }

    private(set) var statuses: [StockDetail.MarketStatus.Response] = []
    func presentMarketStatus(response: StockDetail.MarketStatus.Response) { statuses.append(response) }
}

@MainActor
struct StockDetailInteractorTests {

    private func makeInteractor(worker: WorkerStub, instrument: Instrument? = thyao) -> (StockDetailInteractor, PresenterSpy) {
        let presenter = PresenterSpy()
        let interactor = StockDetailInteractor(presenter: presenter, worker: worker)
        interactor.instrument = instrument   // Router'ın yaptığı DataPassing
        return (interactor, presenter)
    }

    @Test func loadPresentsQuoteAndCandlesForRequestedRange() async {
        let monthCandles = [candle(open: 90, high: 95, low: 88, close: 94)]
        let (interactor, presenter) = makeInteractor(worker: WorkerStub(candlesByRange: [.month: monthCandles]))

        await interactor.load(request: .init(range: .month))

        #expect(presenter.details.count == 1)
        #expect(presenter.details.first?.range == .month)
        #expect(presenter.details.first?.candles == monthCandles)
        #expect(presenter.details.first?.instrument == thyao)
    }

    /// Router veri yazmadıysa (DataStore boş) hata gösterilir.
    @Test func loadWithoutInstrumentPresentsError() async {
        let (interactor, presenter) = makeInteractor(worker: WorkerStub(), instrument: nil)

        await interactor.load(request: .init(range: .day))

        #expect(presenter.errorCount == 1)
        #expect(presenter.details.isEmpty)
    }

    @Test(arguments: [true, false])
    func loadFailurePresentsError(workerThrows: Bool) async {
        let worker = workerThrows ? WorkerStub(fails: true) : WorkerStub(quote: nil)
        let (interactor, presenter) = makeInteractor(worker: worker)

        await interactor.load(request: .init(range: .day))

        #expect(presenter.errorCount == 1)
    }

    /// Canlı fiyat son mumu günceller: kapanış = fiyat, en yüksek genişler.
    @Test func liveQuoteUpdatesTheLastCandle() async {
        let candles = [
            candle(open: 98, high: 100, low: 97, close: 99),
            candle(open: 99, high: 101, low: 98, close: 100),
        ]
        let worker = WorkerStub(candlesByRange: [.day: candles], updates: [.quote(makeQuote(103)), .feedInterrupted])
        let (interactor, presenter) = makeInteractor(worker: worker)
        await interactor.load(request: .init(range: .day))

        await interactor.startLiveUpdates(request: .init())

        #expect(presenter.updates.count == 1)
        let last = presenter.updates.first?.candles.last
        #expect(last?.close == Money(103))
        #expect(last?.high == Money(103))
        #expect(last?.low == Money(98))
        #expect(presenter.updates.first?.candles.first == candles[0])
    }

    // MARK: - Crosshair seçimi

    @Test func selectingAPointPresentsThatCandle() async throws {
        let candles = [candle(open: 98, high: 100, low: 97, close: 99), candle(open: 99, high: 104, low: 98, close: 103)]
        let (interactor, presenter) = makeInteractor(worker: WorkerStub(candlesByRange: [.week: candles]))
        await interactor.load(request: .init(range: .week))

        interactor.selectPoint(request: .init(index: 1))

        guard case let .point(selected, rangeStart, range) = try #require(presenter.selections.first) else {
            Issue.record("Seçili nokta bekleniyordu")
            return
        }
        #expect(selected == candles[1])
        #expect(rangeStart == Money(98))
        #expect(range == .week)
    }

    /// Parmak kalkınca (nil) ya da geçersiz indeks gelince başlık canlı fiyata döner.
    @Test(arguments: [nil, 99] as [Int?])
    func clearingOrInvalidIndexRestoresLiveQuote(index: Int?) async throws {
        let candles = [candle(open: 98, high: 100, low: 97, close: 99)]
        let (interactor, presenter) = makeInteractor(worker: WorkerStub(candlesByRange: [.day: candles]))
        await interactor.load(request: .init(range: .day))

        interactor.selectPoint(request: .init(index: index))

        guard case let .cleared(name, quote) = try #require(presenter.selections.first) else {
            Issue.record("Seçimin temizlenmesi bekleniyordu")
            return
        }
        #expect(name == thyao.name)
        #expect(quote == makeQuote(101))
    }

    // MARK: - İlk kare ve pozisyon

    /// Router'ın aktardığı son fiyat, yükleme beklenmeden hemen gösterilir.
    @Test func prepareShowsInitialQuoteImmediately() {
        let (interactor, presenter) = makeInteractor(worker: WorkerStub())
        interactor.initialQuote = makeQuote(99)

        interactor.prepare()

        #expect(presenter.initials.first?.instrument == thyao)
        #expect(presenter.initials.first?.quote == makeQuote(99))
    }

    /// Portföy akışı: önce pozisyon yok, alımdan sonra var.
    @Test func portfolioChangesPresentHolding() async throws {
        var bought = Portfolio(cash: Money(1_000))
        try bought.execute(Order(symbol: thyao.symbol, side: .buy, quantity: 2), at: makeQuote(100))
        let worker = WorkerStub(portfolios: [Portfolio(cash: Money(1_000)), bought])
        let (interactor, presenter) = makeInteractor(worker: worker)

        await interactor.startLiveUpdates(request: .init())

        #expect(presenter.holdings.count == 2)
        #expect(presenter.holdings.first?.position == nil)
        #expect(presenter.holdings.last?.position?.quantity == 2)
    }

    // MARK: - Uç durumlar

    @Test func haltAndFeedEventsUpdateMarketStatus() async {
        let worker = WorkerStub(updates: [
            .halted(thyao.symbol), .feedInterrupted, .resumed(thyao.symbol), .feedRestored, .halted(Symbol("OTHER")),
        ])
        let (interactor, presenter) = makeInteractor(worker: worker)

        await interactor.startLiveUpdates(request: .init())

        // Başka hissenin durdurulması bu ekranı etkilemez.
        #expect(presenter.statuses.map(\.isHalted) == [true, true, false, false])
        #expect(presenter.statuses.map(\.isFeedInterrupted) == [false, true, true, false])
    }
}
