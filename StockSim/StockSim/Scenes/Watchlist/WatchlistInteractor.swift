import Domain

/// VC'nin Interactor'dan isteyebileceği işler. VC sadece bunu bilir (ISP).
@MainActor
protocol WatchlistBusinessLogic {
    func loadWatchlist(request: Watchlist.Load.Request) async
}

/// Router'ın başka ekrana veri taşırken okuyacağı veriler (Phase 5'te kullanılacak).
@MainActor
protocol WatchlistDataStore {
    var instruments: [Instrument] { get }
}

/// Interactor: iş kuralları. Worker'dan veriyi alır, Presenter'a ham haliyle verir.
/// UI bilmez: UIKit import etmez, string formatlamaz.
@MainActor
final class WatchlistInteractor: WatchlistBusinessLogic, WatchlistDataStore {

    private let presenter: WatchlistPresentationLogic
    private let worker: WatchlistWorking

    private(set) var instruments: [Instrument] = []

    init(presenter: WatchlistPresentationLogic, worker: WatchlistWorking) {
        self.presenter = presenter
        self.worker = worker
    }

    func loadWatchlist(request: Watchlist.Load.Request) async {
        // Veri gelene kadar skeleton.
        presenter.presentLoading()
        do {
            let workerOutput = try await worker.fetchInstruments()
            self.instruments = workerOutput
            // Adım 2: ilk fiyatlar da yükleniyor; Presenter bunları formatlayacak.
            let quotes = try await worker.fetchQuotes(for: workerOutput.map(\.symbol))
            let quotesBySymbol = Dictionary(quotes.map { ($0.symbol, $0) }, uniquingKeysWith: { _, latest in latest })
            presenter.presentWatchlist(response: Watchlist.Load.Response(instruments: self.instruments, quotes: quotesBySymbol))
        } catch {
            presenter.presentLoadError()
        }
    }
}
