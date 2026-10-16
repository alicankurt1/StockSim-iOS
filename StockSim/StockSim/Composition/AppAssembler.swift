import UIKit
import Domain
import MarketSimulator

// Composition root: somut tiplerin oluşturulduğu TEK yer (DIP).
// Sahneler sadece protokolleri bilir; gerçek mi sahte mi veri kaynağı kullanılacağı,
// hangi worker'ın bağlanacağı burada seçilir.
@MainActor
final class AppAssembler {

    /// Uygulama boyunca tek bir piyasa. Phase 9'da burada gerçek veriyle değiştirilebilecek.
    private let market: MarketSimulator
    /// Tek sanal hesap: tüm ekranlar aynı actor'ü paylaşır.
    private let portfolioStore: PortfolioStoring

    init(market: MarketSimulator = MarketSimulator(), portfolioStore: PortfolioStoring = PortfolioStore()) {
        self.market = market
        self.portfolioStore = portfolioStore
    }

    func makeRootViewController() -> UIViewController {
        Task { await market.start() }

        let navigationController = UINavigationController(rootViewController: makeWatchlist())
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
