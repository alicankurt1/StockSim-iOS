import UIKit
import Domain
import MarketSimulator
import Persistence

// Composition root: somut tiplerin oluşturulduğu TEK yer (DIP).
// Sahneler sadece protokolleri bilir; gerçek mi sahte mi veri kaynağı kullanılacağı,
// hangi worker'ın bağlanacağı burada seçilir.
@MainActor
final class AppAssembler {

    /// Uygulama boyunca tek bir piyasa. Phase 9'da burada gerçek veriyle değiştirilebilecek.
    private let market: MarketSimulator
    /// Tek sanal hesap: tüm ekranlar aynı actor'ü paylaşır.
    private let portfolioStore: PortfolioStoring

    init(market: MarketSimulator = MarketSimulator(), portfolioStore: PortfolioStoring = AppAssembler.makePortfolioStore()) {
        self.market = market
        self.portfolioStore = portfolioStore
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
        Task { await market.start() }

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

    /// `-slowLoading` argümanıyla açılırsa Worker'ı geciktiren sarmalayıcıyla kurar (skeleton'ı görmek için).
    private func makeWatchlistWorker() -> WatchlistWorking {
        let worker = WatchlistWorker(market: market)
        guard ProcessInfo.processInfo.arguments.contains("-slowLoading") else { return worker }
        return DelayedWatchlistWorker(base: worker, delay: .seconds(2))
    }
}
