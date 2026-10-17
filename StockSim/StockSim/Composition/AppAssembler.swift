import UIKit
import Domain
import MarketSimulator
import MarketData
import Persistence

/// Fiyatların nereden geldiği. Ekranlar bunu bilmez; sadece composition root seçer.
enum MarketDataSource: String {
    case simulated
    /// Yahoo Finance, ~15 dk gecikmeli.
    case delayed

    var badgeTitle: String {
        switch self {
        case .simulated: "SIMULATED"
        case .delayed: "DELAYED 15M"
        }
    }

    var menuTitle: String {
        switch self {
        case .simulated: "Simulated market"
        case .delayed: "Real data (delayed ~15 min)"
        }
    }
}

// Composition root: somut tiplerin oluşturulduğu TEK yer (DIP).
// Sahneler sadece protokolleri bilir; gerçek mi sahte mi veri kaynağı kullanılacağı,
// hangi worker'ın bağlanacağı burada seçilir.
@MainActor
final class AppAssembler {

    /// Fiyat kaynağı. Ekranlar sadece `MarketDataProviding`'i bilir (LSP): simülatör ya da
    /// gerçek veri birbirinin yerine geçer, hiçbir sahne değişmez.
    private var market: any MarketDataProviding
    /// Hisse arama: simülatörde çevrimdışı rehber, gerçek veride Yahoo (ikisi de aynı protokol).
    private var searcher: any SymbolSearching
    /// Simülatör seçiliyse onu başlatıp durdurmak için (gerçek veride `nil`).
    private var simulator: MarketSimulator?
    private(set) var dataSource: MarketDataSource
    /// Tek sanal hesap: tüm ekranlar aynı actor'ü paylaşır (kaynak değişse de hesap aynı).
    private let portfolioStore: PortfolioStoring
    /// Kişisel izleme listesi: kaynak değişse de aynı liste.
    private let watchlistStore: WatchlistStoring
    /// Takip edilen "ya alsaydım" senaryoları.
    private let whatIfStore: WhatIfStoring
    /// Kaynak değişince kök ekranı yeniden kurmak için.
    weak var window: UIWindow?

    private static let dataSourceKey = "marketDataSource"

    init(
        dataSource: MarketDataSource? = nil,
        portfolioStore: PortfolioStoring = AppAssembler.makePortfolioStore(),
        watchlistStore: WatchlistStoring = AppAssembler.makeWatchlistStore(),
        whatIfStore: WhatIfStoring = AppAssembler.makeWhatIfStore()
    ) {
        let source = dataSource ?? Self.savedDataSource()
        self.dataSource = source
        self.portfolioStore = portfolioStore
        self.watchlistStore = watchlistStore
        self.whatIfStore = whatIfStore
        (market, searcher, simulator) = Self.makeMarket(for: source)
    }

    /// İzleme listesi cihazda kalıcı (`-inMemoryStorage` ile UI testleri temiz başlar).
    static func makeWatchlistStore() -> WatchlistStoring {
        guard !usesInMemoryStorage, let repository = try? FileWatchlistRepository.defaultLocation() else {
            return WatchlistStore()
        }
        return WatchlistStore(repository: repository)
    }

    static func makeWhatIfStore() -> WhatIfStoring {
        guard !usesInMemoryStorage, let repository = try? FileWhatIfRepository.defaultLocation() else {
            return WhatIfStore()
        }
        return WhatIfStore(repository: repository)
    }

    private static var usesInMemoryStorage: Bool {
        ProcessInfo.processInfo.arguments.contains("-inMemoryStorage")
    }

    private static func savedDataSource() -> MarketDataSource {
        if ProcessInfo.processInfo.arguments.contains("-realData") { return .delayed }
        return UserDefaults.standard.string(forKey: dataSourceKey).flatMap(MarketDataSource.init) ?? .simulated
    }

    private static func makeMarket(for source: MarketDataSource) -> (any MarketDataProviding, any SymbolSearching, MarketSimulator?) {
        switch source {
        case .simulated:
            let simulator = MarketSimulator()
            return (simulator, simulator, simulator)
        case .delayed:
            let provider = YahooMarketProvider()
            return (provider, provider, nil)
        }
    }

    /// Kaynağı değiştirir ve tüm ekranları yeni kaynakla baştan kurar.
    func switchDataSource(to source: MarketDataSource) {
        guard source != dataSource else { return }
        if let simulator { Task { await simulator.stop() } }
        dataSource = source
        UserDefaults.standard.set(source.rawValue, forKey: Self.dataSourceKey)
        (market, searcher, simulator) = Self.makeMarket(for: source)

        guard let window else { return }
        let root = makeRootViewController()
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = root
        }
    }

    /// Hesap cihazda bir JSON dosyasında kalıcı. Domain sadece `PortfolioRepository`'yi bilir;
    /// dosya mı, bellek mi burada seçilir (DIP). `-inMemoryStorage`: UI testleri temiz başlasın diye.
    static func makePortfolioStore() -> PortfolioStoring {
        guard !usesInMemoryStorage, let repository = try? FilePortfolioRepository.defaultLocation() else {
            return PortfolioStore()
        }
        return PortfolioStore(repository: repository)
    }

    /// Alt sekmeler: her sekme kendi navigation stack'ine sahip.
    func makeRootViewController() -> UIViewController {
        if let simulator { Task { await simulator.start() } }

        let watchlist = makeNavigationController(root: makeWatchlist())
        watchlist.tabBarItem = UITabBarItem(title: "Watchlist", image: UIImage(systemName: "chart.line.uptrend.xyaxis"), tag: 0)
        let holdings = makeNavigationController(root: makeHoldings())
        holdings.tabBarItem = UITabBarItem(title: "Portfolio", image: UIImage(systemName: "briefcase.fill"), tag: 1)

        let whatIf = makeNavigationController(root: makeWhatIfList())
        whatIf.tabBarItem = UITabBarItem(title: "What If", image: UIImage(systemName: "clock.arrow.circlepath"), tag: 2)

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [watchlist, holdings, whatIf]
        tabBarController.tabBar.tintColor = Theme.Color.accent
        return tabBarController
    }

    private func makeNavigationController(root: UIViewController) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: root)
        navigationController.navigationBar.prefersLargeTitles = true
        Theme.style(navigationController.navigationBar)
        return navigationController
    }

    /// VIP sahnesini kurar ve birbirine bağlar.
    ///
    /// Orijinal Clean Swift şablonunda bu kurulum VC'nin içindeki `setup()`'ta yapılır.
    /// Biz composition root'a taşıdık: VC bağımlılıklarını kendisi seçmez, dışarıdan alır.
    func makeWatchlist() -> UIViewController {
        let presenter = WatchlistPresenter()
        let interactor = WatchlistInteractor(presenter: presenter, worker: makeWatchlistWorker())
        let router = WatchlistRouter(
            dataStore: interactor,
            makeStockDetail: { [unowned self] in self.makeStockDetail() },
            makeSearch: { [unowned self] in self.makeStockSearch() }
        )
        let viewController = WatchlistViewController(interactor: interactor, router: router)
        viewController.navigationItem.rightBarButtonItem = makeDataSourceItem()

        // Geri bağlantılar weak: VC → Interactor → Presenter ⇢ VC, VC → Router ⇢ VC
        presenter.viewController = viewController
        router.viewController = viewController
        return viewController
    }

    func makeStockSearch() -> UIViewController {
        let presenter = StockSearchPresenter()
        let worker = StockSearchWorker(searcher: searcher, watchlist: watchlistStore)
        let interactor = StockSearchInteractor(presenter: presenter, worker: worker)
        let router = StockSearchRouter()
        let viewController = StockSearchViewController(interactor: interactor, router: router)

        presenter.viewController = viewController
        router.viewController = viewController
        return viewController
    }

    /// Detay sahnesini kurar. Router'a veri yazabilsin diye DataStore'u (Interactor) da döner.
    func makeStockDetail() -> (viewController: UIViewController, dataStore: StockDetailDataStore) {
        let presenter = StockDetailPresenter()
        let interactor = StockDetailInteractor(presenter: presenter, worker: StockDetailWorker(market: market, portfolio: portfolioStore))
        let router = StockDetailRouter(dataStore: interactor, makeTradeTicket: { [unowned self] in self.makeTradeTicket() })
        let viewController = StockDetailViewController(interactor: interactor, router: router)

        presenter.viewController = viewController
        router.viewController = viewController
        return (viewController, interactor)
    }

    func makeHoldings() -> UIViewController {
        let presenter = HoldingsPresenter()
        let interactor = HoldingsInteractor(presenter: presenter, worker: HoldingsWorker(market: market, portfolio: portfolioStore))
        let router = HoldingsRouter(dataStore: interactor, makeStockDetail: { [unowned self] in self.makeStockDetail() })
        let viewController = HoldingsViewController(interactor: interactor, router: router)

        presenter.viewController = viewController
        router.viewController = viewController
        return viewController
    }

    func makeWhatIfList() -> UIViewController {
        let presenter = WhatIfListPresenter()
        let interactor = WhatIfListInteractor(presenter: presenter, worker: WhatIfListWorker(market: market, store: whatIfStore))
        let router = WhatIfListRouter(dataStore: interactor, makeBuilder: { [unowned self] in self.makeWhatIfBuilder() })
        let viewController = WhatIfListViewController(interactor: interactor, router: router)

        presenter.viewController = viewController
        router.viewController = viewController
        return viewController
    }

    func makeWhatIfBuilder() -> (viewController: UIViewController, dataStore: WhatIfBuilderDataStore) {
        let presenter = WhatIfBuilderPresenter()
        let worker = WhatIfBuilderWorker(market: market, watchlist: watchlistStore, store: whatIfStore)
        let interactor = WhatIfBuilderInteractor(presenter: presenter, worker: worker)
        let router = WhatIfBuilderRouter()
        let viewController = WhatIfBuilderViewController(interactor: interactor, router: router)

        presenter.viewController = viewController
        router.viewController = viewController
        return (viewController, interactor)
    }

    func makeTradeTicket() -> (viewController: UIViewController, dataStore: TradeTicketDataStore) {
        let presenter = TradeTicketPresenter()
        let worker = TradeTicketWorker(market: market, portfolio: portfolioStore)
        let interactor = TradeTicketInteractor(presenter: presenter, worker: worker)
        let router = TradeTicketRouter()
        let viewController = TradeTicketViewController(interactor: interactor, router: router)

        presenter.viewController = viewController
        router.viewController = viewController
        return (viewController, interactor)
    }

    /// Uç durum tetikleyicileri (sallama ya da rozet menüsü). Gerçek veride yok.
    func showMarketControls() {
        guard let presenter = topViewController() else { return }
        guard let simulator else {
            let alert = UIAlertController(
                title: "Market controls",
                message: "Available in the simulated market. Switch the data source to Simulated to try crashes, halts and feed drops.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
            return
        }
        MarketControlsMenu(simulator: simulator, watchlist: watchlistStore).present(from: presenter)
    }

    /// En üstte görünen ekran (açık bir sayfa varsa o).
    private func topViewController() -> UIViewController? {
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// Watchlist'in sağ üstündeki rozet: kaynağı gösterir, dokununca değiştirme menüsü açılır.
    /// Bu bir uygulama ayarı (iş kuralı değil) ve kökü yeniden kurmayı gerektiriyor;
    /// o yüzden sahnenin değil composition root'un işi.
    private func makeDataSourceItem() -> UIBarButtonItem {
        let actions = [MarketDataSource.simulated, .delayed].map { source in
            UIAction(title: source.menuTitle, state: source == dataSource ? .on : .off) { [weak self] _ in
                self?.switchDataSource(to: source)
            }
        }
        var configuration = UIButton.Configuration.tinted()
        configuration.title = dataSource.badgeTitle
        configuration.baseForegroundColor = dataSource == .simulated ? Theme.Color.accent : Theme.Color.up
        configuration.buttonSize = .mini
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 11, weight: .bold)
            return attributes
        }
        var children: [UIMenuElement] = [UIMenu(options: .displayInline, children: actions)]
        if simulator != nil {
            children.append(UIAction(title: "Market controls…", image: UIImage(systemName: "slider.horizontal.3")) { [weak self] _ in
                self?.showMarketControls()
            })
        }
        let button = UIButton(configuration: configuration)
        button.menu = UIMenu(title: "Market data", children: children)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Market data source: \(dataSource.menuTitle)"
        return UIBarButtonItem(customView: button)
    }

    /// `-slowLoading` argümanıyla açılırsa Worker'ı geciktiren sarmalayıcıyla kurar (skeleton'ı görmek için).
    private func makeWatchlistWorker() -> WatchlistWorking {
        let worker = WatchlistWorker(market: market, watchlist: watchlistStore)
        guard ProcessInfo.processInfo.arguments.contains("-slowLoading") else { return worker }
        return DelayedWatchlistWorker(base: worker, delay: .seconds(2))
    }
}
