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

    init(market: MarketSimulator = MarketSimulator()) {
        self.market = market
    }

    func makeRootViewController() -> UIViewController {
        Task { await market.start() }

        let navigationController = UINavigationController(rootViewController: makeWatchlist())
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    /// VIP sahnesini kurar ve birbirine bağlar.
    ///
    /// Orijinal Clean Swift şablonunda bu kurulum VC'nin içindeki `setup()`'ta yapılır.
    /// Biz composition root'a taşıdık: VC bağımlılıklarını kendisi seçmez, dışarıdan alır.
    func makeWatchlist() -> UIViewController {
        let presenter = WatchlistPresenter()
        let interactor = WatchlistInteractor(presenter: presenter, worker: WatchlistWorker(market: market))
        let router = WatchlistRouter(dataStore: interactor)
        let viewController = WatchlistViewController(interactor: interactor, router: router)

        // Geri bağlantılar weak: VC → Interactor → Presenter ⇢ VC, VC → Router ⇢ VC
        presenter.viewController = viewController
        router.viewController = viewController
        return viewController
    }
}
