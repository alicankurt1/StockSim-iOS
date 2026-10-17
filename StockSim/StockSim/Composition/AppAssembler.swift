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
    /// Simülatör seçiliyse onu başlatıp durdurmak için (gerçek veride `nil`).
    private var simulator: MarketSimulator?
    private(set) var dataSource: MarketDataSource
    /// Tek sanal hesap: tüm ekranlar aynı actor'ü paylaşır (kaynak değişse de hesap aynı).
    private let portfolioStore: PortfolioStoring
    /// Kaynak değişince kök ekranı yeniden kurmak için.
    weak var window: UIWindow?

    private static let dataSourceKey = "marketDataSource"

    init(dataSource: MarketDataSource? = nil, portfolioStore: PortfolioStoring = AppAssembler.makePortfolioStore()) {
        let source = dataSource ?? Self.savedDataSource()
        self.dataSource = source
        self.portfolioStore = portfolioStore
        (market, simulator) = Self.makeMarket(for: source)
    }

    private static func savedDataSource() -> MarketDataSource {
        if ProcessInfo.processInfo.arguments.contains("-realData") { return .delayed }
        return UserDefaults.standard.string(forKey: dataSourceKey).flatMap(MarketDataSource.init) ?? .simulated
    }

    private static func makeMarket(for source: MarketDataSource) -> (any MarketDataProviding, MarketSimulator?) {
        switch source {
        case .simulated:
            let simulator = MarketSimulator()
            return (simulator, simulator)
        case .delayed:
            return (YahooMarketProvider(), nil)
        }
    }

    /// Kaynağı değiştirir ve tüm ekranları yeni kaynakla baştan kurar.
    func switchDataSource(to source: MarketDataSource) {
        guard source != dataSource else { return }
        if let simulator { Task { await simulator.stop() } }
        dataSource = source
        UserDefaults.standard.set(source.rawValue, forKey: Self.dataSourceKey)
        (market, simulator) = Self.makeMarket(for: source)

        guard let window else { return }
        let root = makeRootViewController()
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = root
        }
    }

    /// Hesap cihazda bir JSON dosyasında kalıcı. Domain sadece `PortfolioRepository`'yi bilir;
    /// dosya mı, bellek mi burada seçilir (DIP). `-inMemoryPortfolio`: UI testleri temiz başlasın diye.
    static func makePortfolioStore() -> PortfolioStoring {
        let arguments = ProcessInfo.processInfo.arguments
        guard !arguments.contains("-inMemoryPortfolio"), let repository = try? FilePortfolioRepository.defaultLocation() else {
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

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [watchlist, holdings]
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
        let router = WatchlistRouter(dataStore: interactor, makeStockDetail: { [unowned self] in self.makeStockDetail() })
        let viewController = WatchlistViewController(interactor: interactor, router: router)
        viewController.navigationItem.rightBarButtonItem = makeDataSourceItem()

        // Geri bağlantılar weak: VC → Interactor → Presenter ⇢ VC, VC → Router ⇢ VC
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
        let button = UIButton(configuration: configuration)
        button.menu = UIMenu(title: "Market data", children: actions)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Market data source: \(dataSource.menuTitle)"
        return UIBarButtonItem(customView: button)
    }

    /// `-slowLoading` argümanıyla açılırsa Worker'ı geciktiren sarmalayıcıyla kurar (skeleton'ı görmek için).
    private func makeWatchlistWorker() -> WatchlistWorking {
        let worker = WatchlistWorker(market: market)
        guard ProcessInfo.processInfo.arguments.contains("-slowLoading") else { return worker }
        return DelayedWatchlistWorker(base: worker, delay: .seconds(2))
    }
}
