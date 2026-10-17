import Foundation
import Testing
import UIKit
import Domain
@testable import StockSim

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let asels = Instrument(symbol: Symbol("ASELS"), name: "Aselsan")
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 86_400

private func candle(daysAgo: Double, open: Decimal, close: Decimal) -> Candle {
    Candle(date: now.addingTimeInterval(-daysAgo * day), open: Money(open), high: Money(max(open, close)), low: Money(min(open, close)), close: Money(close))
}

// MARK: - Builder interactor

@MainActor
private final class BuilderWorkerFake: WhatIfBuilderWorking {
    var candles: [Candle] = [
        candle(daysAgo: 200, open: 200, close: 210),
        candle(daysAgo: 100, open: 250, close: 255),
        candle(daysAgo: 7, open: 290, close: 295),
    ]
    var price = Money(300)
    private(set) var requestedRanges: [ChartRange] = []
    private(set) var tracked: [WhatIfScenario] = []
    private(set) var updated: [WhatIfScenario] = []

    func instruments() async -> [Instrument] { [thyao, asels] }
    func history(for symbol: Symbol, range: ChartRange) async throws -> [Candle] {
        requestedRanges.append(range)
        return candles
    }
    func quote(for symbol: Symbol) async throws -> Quote? {
        Quote(symbol: symbol, price: price, previousClose: price, timestamp: now)
    }
    func track(_ scenario: WhatIfScenario) async { tracked.append(scenario) }
    func update(_ scenario: WhatIfScenario) async { updated.append(scenario) }
}

@MainActor
private final class BuilderPresenterSpy: WhatIfBuilderPresentationLogic {
    private(set) var responses: [WhatIfBuilder.Response] = []
    private(set) var trackedCount = 0
    func presentBuilder(response: WhatIfBuilder.Response) { responses.append(response) }
    func presentTracked(response: WhatIfBuilder.Track.Response) { trackedCount += 1 }

    var lastScenario: WhatIfScenario? {
        if case let .result(scenario, _, _) = responses.last?.outcome { scenario } else { nil }
    }
}

@MainActor
struct WhatIfBuilderInteractorTests {

    private func make() -> (WhatIfBuilderInteractor, BuilderPresenterSpy, BuilderWorkerFake) {
        let presenter = BuilderPresenterSpy()
        let worker = BuilderWorkerFake()
        return (WhatIfBuilderInteractor(presenter: presenter, worker: worker, now: { now }), presenter, worker)
    }

    /// Varsayılan: ilk hisse, 6 ay önce, 100.000 ₺ → ~100 gün önceki mumun açılışından alım.
    @Test func loadCalculatesDefaultScenario() async throws {
        let (interactor, presenter, worker) = make()

        await interactor.load()

        let scenario = try #require(presenter.lastScenario)
        #expect(scenario.instrument == thyao)
        #expect(scenario.amount == Money(100_000))
        #expect(scenario.entryPrice == Money(250))
        #expect(worker.requestedRanges == [.year])
    }

    /// Son 1 ay içindeki tarih → günlük mumlar (.month).
    @Test func recentDateUsesDailyCandles() async {
        let (interactor, _, worker) = make()
        await interactor.load()

        await interactor.edit(request: .init(date: now.addingTimeInterval(-10 * day)))

        #expect(worker.requestedRanges.last == .month)
    }

    @Test(arguments: [("", false), ("0", false), ("abc", false), ("50.000", true)])
    func amountValidation(text: String, valid: Bool) async {
        let (interactor, presenter, _) = make()
        await interactor.load()

        await interactor.edit(request: .init(amountText: text))

        if valid {
            #expect(presenter.lastScenario?.amount == Money(50_000))
        } else if case .invalidAmount = presenter.responses.last?.outcome {
            // beklenen
        } else {
            Issue.record("Geçersiz tutar bekleniyordu: \(text)")
        }
    }

    @Test func trackSavesTheScenario() async throws {
        let (interactor, presenter, worker) = make()
        await interactor.load()

        await interactor.track()

        #expect(worker.tracked.count == 1)
        #expect(worker.tracked.first == presenter.lastScenario)
        #expect(presenter.trackedCount == 1)
    }

    // MARK: Düzenleme modu

    /// Router'ın yazdığı senaryo formu doldurur; izleme listesinde olmayan hisse de seçilebilir.
    @Test func editingPrefillsTheForm() async throws {
        let (interactor, presenter, _) = make()
        let aksa = Instrument(symbol: Symbol("AKSA"), name: "Aksa Akrilik")
        interactor.editing = WhatIfScenario(instrument: aksa, amount: Money(5_000), startDate: now.addingTimeInterval(-150 * day), entryPrice: Money(10))

        await interactor.load()

        let response = try #require(presenter.responses.last)
        #expect(response.isEditing)
        #expect(response.instrument == aksa)
        #expect(response.instruments.first == aksa)
        #expect(response.amount == Money(5_000))
    }

    /// Kaydet: aynı kimlikle güncelle, yeni senaryo ekleme.
    @Test func savingAnEditUpdatesInPlace() async throws {
        let (interactor, _, worker) = make()
        let original = WhatIfScenario(instrument: thyao, amount: Money(5_000), startDate: now.addingTimeInterval(-150 * day), entryPrice: Money(10))
        interactor.editing = original
        await interactor.load()
        await interactor.edit(request: .init(amountText: "7.500"))

        await interactor.track()

        #expect(worker.tracked.isEmpty)
        #expect(worker.updated.first?.id == original.id)
        #expect(worker.updated.first?.amount == Money(7_500))
    }

    /// Türkçe biçim: nokta binlik, virgül ondalık.
    @Test(arguments: [
        ("100000", "100000"), ("100.000", "100000"), ("1.250,50", "1250.5"), ("₺ 2.000", "2000"),
    ])
    func parseAmount(text: String, expected: String) {
        #expect(WhatIfBuilderInteractor.parseAmount(text) == Money(Decimal(string: expected)!))
    }
}

// MARK: - Presenters

@MainActor
private final class BuilderDisplaySpy: WhatIfBuilderDisplayLogic {
    private(set) var viewModels: [WhatIfBuilder.ViewModel] = []
    func displayBuilder(viewModel: WhatIfBuilder.ViewModel) { viewModels.append(viewModel) }
    func displayTracked() {}
}

@MainActor
private final class ListDisplaySpy: WhatIfListDisplayLogic {
    private(set) var viewModels: [WhatIfList.ViewModel] = []
    func displayList(viewModel: WhatIfList.ViewModel) { viewModels.append(viewModel) }
}

@MainActor
struct WhatIfPresenterTests {

    /// 100.000 ₺ @250 = 400 adet; bugün 300 → 120.000 (+20.000, +%20).
    private let scenario = WhatIfScenario(instrument: thyao, amount: Money(100_000), startDate: now, entryPrice: Money(250))

    @Test func builderResultTexts() throws {
        let presenter = WhatIfBuilderPresenter()
        let display = BuilderDisplaySpy()
        presenter.viewController = display
        let candles = [candle(daysAgo: 100, open: 250, close: 260), candle(daysAgo: 1, open: 290, close: 295)]

        presenter.presentBuilder(response: .init(
            isEditing: false,
            instruments: [thyao], instrument: thyao, date: now, dateRange: now...now, amount: Money(100_000),
            outcome: .result(scenario, currentPrice: Money(300), candles: candles)
        ))

        let result = try #require(display.viewModels.first?.result)
        #expect(result.entry.hasPrefix("Bought 400 shares at ₺250,00 on "))
        #expect(result.value == "₺120.000,00")
        #expect(result.profitLoss == "+₺20.000,00 (+%20,00)")
        #expect(result.baseline == 250)
        #expect(result.chart == [260, 300])   // son nokta canlı fiyat
        #expect(display.viewModels.first?.isTrackEnabled == true)
        #expect(display.viewModels.first?.trackTitle == "Track this")
        #expect(display.viewModels.first?.amountText == "100.000")
    }

    @Test func listRowUsesLivePriceOrEntryPrice() throws {
        let presenter = WhatIfListPresenter()
        let display = ListDisplaySpy()
        presenter.viewController = display

        presenter.presentList(response: .init(scenarios: [scenario], prices: [thyao.symbol: Money(300)]))
        presenter.presentList(response: .init(scenarios: [scenario], prices: [:]))

        let row = try #require(display.viewModels.first?.rows.first)
        #expect(row.value == "₺120.000,00")
        #expect(row.returnText == "+%20,00")
        #expect(row.subtitle.hasSuffix(" · ₺100.000"))
        #expect(display.viewModels.last?.rows.first?.returnText == "%0,00")
    }

    @Test func emptyListShowsHint() throws {
        let presenter = WhatIfListPresenter()
        let display = ListDisplaySpy()
        presenter.viewController = display

        presenter.presentList(response: .init(scenarios: [], prices: [:]))

        #expect(display.viewModels.first?.emptyMessage != nil)
    }

    @Test(arguments: [(Decimal(400), "400"), (Decimal(string: "347.826")!, "347,83")])
    func sharesFormatting(value: Decimal, expected: String) {
        #expect(WhatIfBuilderPresenter.shares(value) == expected)
    }
}

// MARK: - Router (DataPassing)

@MainActor
private final class BuilderStoreSpy: WhatIfBuilderDataStore {
    var editing: WhatIfScenario?
}

@MainActor
private struct ListStoreStub: WhatIfListDataStore {
    let scenarios: [WhatIfScenario]
    func scenario(for id: UUID) -> WhatIfScenario? { scenarios.first { $0.id == id } }
}

@MainActor
struct WhatIfListRouterTests {

    /// Satıra dokununca: listedeki senaryo oluşturucunun DataStore'una yazılır.
    @Test func editPassesTheScenario() {
        let scenario = WhatIfScenario(instrument: thyao, amount: Money(1), startDate: now, entryPrice: Money(1))
        let destination = BuilderStoreSpy()
        let router = WhatIfListRouter(dataStore: ListStoreStub(scenarios: [scenario])) { (UIViewController(), destination) }

        router.routeToEdit(id: scenario.id)

        #expect(destination.editing == scenario)
    }

    @Test func newScenarioPassesNothing() {
        let destination = BuilderStoreSpy()
        let router = WhatIfListRouter(dataStore: ListStoreStub(scenarios: [])) { (UIViewController(), destination) }

        router.routeToBuilder()

        #expect(destination.editing == nil)
    }
}
