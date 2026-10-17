import Foundation
import Testing
import Domain
@testable import StockSim

// MARK: - Test dublörleri

/// Worker sahtesi (stub): ne döneceğini test belirler.
private struct WorkerStub: WatchlistWorking {
    var result: Result<[Instrument], any Error>
    var quotes: [Quote] = []
    /// Canlı akışta sırayla yollanacak olaylar; sonra akış biter.
    var updates: [MarketUpdate] = []
    var sparklines: [Symbol: [Money]] = [:]

    func fetchIntradayCloses(for symbols: [Symbol]) async -> [Symbol: [Money]] {
        sparklines.filter { symbols.contains($0.key) }
    }

    func fetchInstruments() async throws -> [Instrument] {
        try result.get()
    }

    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote] {
        quotes.filter { symbols.contains($0.symbol) }
    }

    // İzleme listesi: bu testlerde değişmiyor.
    func watchlistChanges() async -> AsyncStream<[Instrument]> { AsyncStream { $0.finish() } }
    func removeFromWatchlist(_ symbol: Symbol) async {}
    func reorderWatchlist(_ symbols: [Symbol]) async {}

    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> {
        // Sonlu akış: test `await` ettiğinde döngü biter ve sonuçlar kontrol edilebilir.
        AsyncStream { continuation in
            for update in updates { continuation.yield(update) }
            continuation.finish()
        }
    }
}

/// Presenter casusu (spy): kendisine ne gönderildiğini kaydeder, test sonra kontrol eder.
@MainActor
private final class PresenterSpy: WatchlistPresentationLogic {
    private(set) var presentedResponses: [Watchlist.Load.Response] = []
    private(set) var loadErrorCount = 0
    /// Çağrı sırasını da kaydediyoruz: "önce loading, sonra veri" kontrolü için.
    private(set) var calls: [String] = []

    func presentLoading() {
        calls.append("loading")
    }

    func presentWatchlist(response: Watchlist.Load.Response) {
        presentedResponses.append(response)
        calls.append("watchlist")
    }

    func presentLoadError() {
        loadErrorCount += 1
        calls.append("error")
    }

    private(set) var quoteUpdates: [Watchlist.Update.Response] = []

    func presentQuoteUpdate(response: Watchlist.Update.Response) {
        quoteUpdates.append(response)
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

    @Test(arguments: [true, false])
    func loadShowsLoadingBeforeResult(succeeds: Bool) async {
        let presenter = PresenterSpy()
        let result: Result<[Instrument], any Error> = succeeds ? .success(instruments) : .failure(SomeError())
        let interactor = WatchlistInteractor(presenter: presenter, worker: WorkerStub(result: result))

        await interactor.loadWatchlist(request: .init())

        #expect(presenter.calls == ["loading", succeeds ? "watchlist" : "error"])
    }

    @Test func loadPassesQuotesKeyedBySymbol() async {
        let quote = Quote(symbol: Symbol("THYAO"), price: Money(290), previousClose: Money(287), timestamp: .now)
        let presenter = PresenterSpy()
        let worker = WorkerStub(result: .success(instruments), quotes: [quote])
        let interactor = WatchlistInteractor(presenter: presenter, worker: worker)

        await interactor.loadWatchlist(request: .init())

        #expect(presenter.presentedResponses.first?.quotes == [Symbol("THYAO"): quote])
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

    // MARK: - Canlı akış

    @Test func liveUpdatesForwardQuotesForLoadedInstruments() async {
        let thyaoQuote = Quote(symbol: Symbol("THYAO"), price: Money(291), previousClose: Money(287), timestamp: .now)
        let unknownQuote = Quote(symbol: Symbol("NOPE"), price: Money(1), previousClose: Money(1), timestamp: .now)
        let presenter = PresenterSpy()
        let worker = WorkerStub(
            result: .success(instruments),
            updates: [.quote(thyaoQuote), .feedInterrupted, .quote(unknownQuote), .halted(Symbol("ASELS"))]
        )
        let interactor = WatchlistInteractor(presenter: presenter, worker: worker)
        await interactor.loadWatchlist(request: .init())

        await interactor.startLiveUpdates(request: .init())

        // Sadece listedeki hisselerin fiyatları Presenter'a gider; diğer olaylar şimdilik yok sayılır.
        #expect(presenter.quoteUpdates.count == 1)
        #expect(presenter.quoteUpdates.first?.instrument == instruments[0])
        #expect(presenter.quoteUpdates.first?.quote == thyaoQuote)
    }

    @Test func liveUpdatesBeforeLoadForwardNothing() async {
        let quote = Quote(symbol: Symbol("THYAO"), price: Money(291), previousClose: Money(287), timestamp: .now)
        let presenter = PresenterSpy()
        let interactor = WatchlistInteractor(presenter: presenter, worker: WorkerStub(result: .success(instruments), updates: [.quote(quote)]))

        await interactor.startLiveUpdates(request: .init())

        #expect(presenter.quoteUpdates.isEmpty)
    }

    // MARK: - Sparkline

    @Test func loadPassesSparklines() async {
        let series = [Money(100), Money(101), Money(99)]
        let presenter = PresenterSpy()
        let worker = WorkerStub(result: .success(instruments), sparklines: [Symbol("THYAO"): series])
        let interactor = WatchlistInteractor(presenter: presenter, worker: worker)

        await interactor.loadWatchlist(request: .init())

        #expect(presenter.presentedResponses.first?.sparklines == [Symbol("THYAO"): series])
    }

    /// Canlı fiyat yeni nokta eklemez; serinin son noktasını günceller.
    @Test func liveQuoteReplacesLastSparklinePoint() async {
        let quote = Quote(symbol: Symbol("THYAO"), price: Money(105), previousClose: Money(100), timestamp: .now)
        let presenter = PresenterSpy()
        let worker = WorkerStub(
            result: .success(instruments),
            updates: [.quote(quote)],
            sparklines: [Symbol("THYAO"): [Money(100), Money(101), Money(99)]]
        )
        let interactor = WatchlistInteractor(presenter: presenter, worker: worker)
        await interactor.loadWatchlist(request: .init())

        await interactor.startLiveUpdates(request: .init())

        #expect(presenter.quoteUpdates.first?.sparkline == [Money(100), Money(101), Money(105)])
    }
}
