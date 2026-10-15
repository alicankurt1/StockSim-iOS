import Testing
import Domain
@testable import StockSim

// MARK: - Test dublörleri

/// Worker sahtesi (stub): ne döneceğini test belirler.
private struct WorkerStub: WatchlistWorking {
    var result: Result<[Instrument], any Error>

    func fetchInstruments() async throws -> [Instrument] {
        try result.get()
    }
}

/// Presenter casusu (spy): kendisine ne gönderildiğini kaydeder, test sonra kontrol eder.
@MainActor
private final class PresenterSpy: WatchlistPresentationLogic {
    private(set) var presentedResponses: [Watchlist.Load.Response] = []
    private(set) var loadErrorCount = 0

    func presentWatchlist(response: Watchlist.Load.Response) {
        presentedResponses.append(response)
    }

    func presentLoadError() {
        loadErrorCount += 1
    }
}

private struct SomeError: Error {}

private let instruments = [
    Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları"),
    Instrument(symbol: Symbol("ASELS"), name: "Aselsan"),
]

// MARK: - Testler

/// Interactor'ı UI olmadan test ediyoruz: gerçek Worker ve Presenter yerine sahteleri veriyoruz.
@MainActor
struct WatchlistInteractorTests {

    @Test func loadPassesInstrumentsToPresenter() async {
        let presenter = PresenterSpy()
        let interactor = WatchlistInteractor(presenter: presenter, worker: WorkerStub(result: .success(instruments)))

        await interactor.loadWatchlist(request: .init())

        #expect(presenter.presentedResponses.count == 1)
        #expect(presenter.presentedResponses.first?.instruments == instruments)
        #expect(presenter.loadErrorCount == 0)
    }

    @Test func loadStoresInstrumentsForRouting() async {
        let interactor = WatchlistInteractor(presenter: PresenterSpy(), worker: WorkerStub(result: .success(instruments)))

        await interactor.loadWatchlist(request: .init())

        #expect(interactor.instruments == instruments)
    }

    @Test func loadFailurePresentsError() async {
        let presenter = PresenterSpy()
        let interactor = WatchlistInteractor(presenter: presenter, worker: WorkerStub(result: .failure(SomeError())))

        await interactor.loadWatchlist(request: .init())

        #expect(presenter.loadErrorCount == 1)
        #expect(presenter.presentedResponses.isEmpty)
    }
}
