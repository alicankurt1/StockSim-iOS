import Domain

/// VC'nin Interactor'dan isteyebileceği işler. VC sadece bunu bilir (ISP).
@MainActor
protocol WatchlistBusinessLogic {
    func loadWatchlist(request: Watchlist.Load.Request) async
    /// Akış bitene ya da çağıran Task iptal edilene kadar döner.
    func startLiveUpdates(request: Watchlist.Update.Request) async
    func removeStock(request: Watchlist.Remove.Request) async
    func reorder(request: Watchlist.Reorder.Request) async
}

/// Router'ın başka ekrana veri taşırken okuyacağı veriler.
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
            try await reload(with: try await worker.fetchInstruments())
        } catch {
            presenter.presentLoadError()
        }
    }

    /// İki akışı aynı anda dinler: fiyatlar ve izleme listesinin kendisi (ekleme/çıkarma/sıra).
    func startLiveUpdates(request: Watchlist.Update.Request) async {
        async let market: Void = listenToMarket()
        async let watchlist: Void = listenToWatchlist()
        _ = await (market, watchlist)
    }

    func removeStock(request: Watchlist.Remove.Request) async {
        // Ekranı burada güncellemiyoruz: depo değişikliği yayınlar, `listenToWatchlist` yeniler.
        // Tek doğruluk kaynağı depo; arama ekranından yapılan eklemeler de aynı yoldan gelir.
        await worker.removeFromWatchlist(request.symbol)
    }

    func reorder(request: Watchlist.Reorder.Request) async {
        await worker.reorderWatchlist(request.symbols)
    }

    // MARK: - Yükleme

    /// Listeyi verilen hisselere göre günceller. Sadece YENİ hisselerin fiyatı ve grafiği
    /// istenir; zaten bilinenler tekrar indirilmez (gerçek veride her biri bir ağ isteği).
    private func reload(with list: [Instrument]) async throws {
        instruments = list
        let symbols = list.map(\.symbol)
        let missing = symbols.filter { quotes[$0] == nil }

        if !missing.isEmpty {
            let fetched = try await worker.fetchQuotes(for: missing)
            fetched.forEach { quotes[$0.symbol] = $0 }
            let closes = await worker.fetchIntradayCloses(for: missing)
            sparklines.merge(closes) { _, new in new }
        }
        // Beklerken liste yine değiştiyse bu sonuç eskidi; yenisi zaten yolda.
        guard instruments.map(\.symbol) == symbols else { return }

        let kept = Set(symbols)
        quotes = quotes.filter { kept.contains($0.key) }
        sparklines = sparklines.filter { kept.contains($0.key) }
        presenter.presentWatchlist(response: Watchlist.Load.Response(
            instruments: instruments, quotes: quotes, sparklines: sparklines
        ))
    }

    // MARK: - Akışlar

    private func listenToWatchlist() async {
        for await list in await worker.watchlistChanges() where list != instruments {
            try? await reload(with: list)
        }
    }

    /// Fiyat akışı listedeki hisselere abone olur. Liste değişince eski akış bırakılır ve
    /// yeni hisselerle yeniden abone olunur (eski aboneliği simülatör/sağlayıcı temizler).
    private func listenToMarket() async {
        while !Task.isCancelled {
            let symbols = instruments.map(\.symbol)
            var listChanged = false

            for await update in await worker.liveUpdates(for: symbols) {
                if instruments.map(\.symbol) != symbols {
                    listChanged = true
                    break
                }
                handle(update)
            }
            // Akış kendiliğinden bittiyse (iptal ya da sonlu akış) çık; liste değiştiyse yeniden abone ol.
            guard listChanged else { return }
        }
    }

    private func handle(_ update: MarketUpdate) {
        switch update {
        case let .quote(quote):
            guard let instrument = instruments.first(where: { $0.symbol == quote.symbol }) else { return }
            quotes[quote.symbol] = quote
            updateSparkline(with: quote)
            presenter.presentQuoteUpdate(response: Watchlist.Update.Response(
                instrument: instrument, quote: quote, sparkline: sparklines[quote.symbol] ?? []
            ))
        case .halted, .resumed, .feedInterrupted, .feedRestored:
            // Phase 11'de: işlem durdu rozeti ve "veri eski" uyarısı.
            return
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
