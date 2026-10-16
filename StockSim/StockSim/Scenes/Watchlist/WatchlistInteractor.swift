import Domain

/// VC'nin Interactor'dan isteyebileceği işler. VC sadece bunu bilir (ISP).
@MainActor
protocol WatchlistBusinessLogic {
    func loadWatchlist(request: Watchlist.Load.Request) async
    /// Akış bitene ya da çağıran Task iptal edilene kadar döner.
    func startLiveUpdates(request: Watchlist.Update.Request) async
}

/// Router'ın başka ekrana veri taşırken okuyacağı veriler (Phase 5'te kullanılacak).
@MainActor
protocol WatchlistDataStore {
    var instruments: [Instrument] { get }
    /// Bilinen son fiyatlar: detay ekranı boş açılmasın diye Router aktarır.
    var quotes: [Symbol: Quote] { get }
}

/// Interactor: iş kuralları. Worker'dan veriyi alır, Presenter'a ham haliyle verir.
/// UI bilmez: UIKit import etmez, string formatlamaz.
@MainActor
final class WatchlistInteractor: WatchlistBusinessLogic, WatchlistDataStore {

    private let presenter: WatchlistPresentationLogic
    private let worker: WatchlistWorking

    private(set) var instruments: [Instrument] = []
    private(set) var quotes: [Symbol: Quote] = [:]
    /// Sparkline serileri; canlı fiyat geldikçe son değer güncellenir.
    private var sparklines: [Symbol: [Money]] = [:]

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
            self.quotes = quotesBySymbol
            sparklines = await worker.fetchIntradayCloses(for: workerOutput.map(\.symbol))
            presenter.presentWatchlist(response: Watchlist.Load.Response(
                instruments: self.instruments, quotes: quotesBySymbol, sparklines: sparklines
            ))
        } catch {
            presenter.presentLoadError()
        }
    }

    func startLiveUpdates(request: Watchlist.Update.Request) async {
        let instrumentsBySymbol = Dictionary(instruments.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
        let updates = await worker.liveUpdates(for: Array(instrumentsBySymbol.keys))

        // `for await`: her yeni olayda döngü bir tur döner. Çağıran Task iptal edilince
        // (ekran kapanınca) akış biter, döngüden çıkılır ve simülatör aboneliği temizler.
        for await update in updates {
            switch update {
            case let .quote(quote):
                guard let instrument = instrumentsBySymbol[quote.symbol] else { continue }
                quotes[quote.symbol] = quote
                updateSparkline(with: quote)
                presenter.presentQuoteUpdate(response: Watchlist.Update.Response(
                    instrument: instrument, quote: quote, sparkline: sparklines[quote.symbol] ?? []
                ))
            case .halted, .resumed, .feedInterrupted, .feedRestored:
                // Phase 11'de: işlem durdu rozeti ve "veri eski" uyarısı.
                continue
            }
        }
    }

    /// Serinin son noktası "şu anki" fiyattır: yeni nokta eklemek yerine onu güncelliyoruz.
    /// Böylece grafiğin ölçeği (5 dakikalık mumlar) bozulmaz, sadece ucu canlı oynar.
    private func updateSparkline(with quote: Quote) {
        guard var series = sparklines[quote.symbol], !series.isEmpty else { return }
        series[series.count - 1] = quote.price
        sparklines[quote.symbol] = series
    }
}
