import Foundation
import Testing
import Domain
@testable import StockSim

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let aksa = Instrument(symbol: Symbol("AKSA"), name: "Aksa Akrilik")

private func quote(_ instrument: Instrument, _ price: Decimal) -> Quote {
    Quote(symbol: instrument.symbol, price: Money(price), previousClose: Money(price), timestamp: .now)
}

/// İzleme listesi değişikliklerini ve istenen fiyatları kaydeden sahte worker.
@MainActor
private final class WorkerFake: WatchlistWorking {
    var list: [Instrument]
    var listChanges: [[Instrument]] = []
    private(set) var quoteRequests: [[Symbol]] = []
    private(set) var removed: [Symbol] = []
    private(set) var reordered: [[Symbol]] = []

    init(list: [Instrument]) { self.list = list }

    func fetchInstruments() async throws -> [Instrument] { list }
    func watchlistChanges() async -> AsyncStream<[Instrument]> {
        let changes = listChanges
        return AsyncStream { continuation in
            changes.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
    func removeFromWatchlist(_ symbol: Symbol) async { removed.append(symbol) }
    func reorderWatchlist(_ symbols: [Symbol]) async { reordered.append(symbols) }
    func fetchQuotes(for symbols: [Symbol]) async throws -> [Quote] {
        quoteRequests.append(symbols)
        return symbols.map { quote(Instrument(symbol: $0, name: ""), 100) }
    }
    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> { AsyncStream { $0.finish() } }
    func fetchIntradayCloses(for symbols: [Symbol]) async -> [Symbol: [Money]] { [:] }
}

@MainActor
private final class PresenterSpy: WatchlistPresentationLogic {
    private(set) var responses: [Watchlist.Load.Response] = []
    func presentLoading() {}
    func presentWatchlist(response: Watchlist.Load.Response) { responses.append(response) }
    func presentLoadError() {}
    func presentQuoteUpdate(response: Watchlist.Update.Response) {}
    func presentFeedStatus(response: Watchlist.FeedStatus.Response) {}
}

@MainActor
struct WatchlistEditingTests {

    /// Arama ekranından hisse eklenince liste yenilenir; sadece YENİ hissenin fiyatı istenir.
    @Test func addedStockAppearsAndOnlyItIsFetched() async {
        let worker = WorkerFake(list: [thyao])
        worker.listChanges = [[thyao], [thyao, aksa]]
        let presenter = PresenterSpy()
        let interactor = WatchlistInteractor(presenter: presenter, worker: worker)
        await interactor.loadWatchlist(request: .init())

        await interactor.startLiveUpdates(request: .init())

        #expect(presenter.responses.last?.instruments == [thyao, aksa])
        #expect(worker.quoteRequests == [[thyao.symbol], [aksa.symbol]])
    }

    /// Çıkarılan hissenin fiyatı da listeden düşer.
    @Test func removedStockDisappears() async {
        let worker = WorkerFake(list: [thyao, aksa])
        worker.listChanges = [[aksa]]
        let presenter = PresenterSpy()
        let interactor = WatchlistInteractor(presenter: presenter, worker: worker)
        await interactor.loadWatchlist(request: .init())

        await interactor.startLiveUpdates(request: .init())

        #expect(presenter.responses.last?.instruments == [aksa])
        #expect(presenter.responses.last?.quotes[thyao.symbol] == nil)
    }

    @Test func removeAndReorderGoToTheStore() async {
        let worker = WorkerFake(list: [thyao, aksa])
        let interactor = WatchlistInteractor(presenter: PresenterSpy(), worker: worker)

        await interactor.removeStock(request: .init(symbol: thyao.symbol))
        await interactor.reorder(request: .init(symbols: [aksa.symbol, thyao.symbol]))

        #expect(worker.removed == [thyao.symbol])
        #expect(worker.reordered == [[aksa.symbol, thyao.symbol]])
    }
}
