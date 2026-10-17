import UIKit
import Domain

/// Ekranlar arası geçişler.
@MainActor
protocol WatchlistRoutingLogic {
    func routeToStockDetail(symbol: Symbol)
    func routeToSearch()
}

/// Arama ekranını kurar. Veri aktarımı yok: arama ekranı izleme listesine doğrudan yazar.
typealias StockSearchFactory = @MainActor () -> UIViewController

/// Hedef ekranı kuran fabrika: VC'yi ve veri yazılacak DataStore'unu birlikte verir.
/// Router somut sahneyi kendisi kurmaz; composition root'tan alır (DIP).
typealias StockDetailFactory = @MainActor () -> (viewController: UIViewController, dataStore: StockDetailDataStore)

@MainActor
final class WatchlistRouter: WatchlistRoutingLogic {

    /// `weak`: VC zaten Router'ı tutuyor.
    weak var viewController: UIViewController?
    /// Kaynak veri: hangi hisseler yüklü.
    let dataStore: WatchlistDataStore
    private let makeStockDetail: StockDetailFactory
    private let makeSearch: StockSearchFactory

    init(
        dataStore: WatchlistDataStore,
        makeStockDetail: @escaping StockDetailFactory,
        makeSearch: @escaping StockSearchFactory = { UIViewController() }
    ) {
        self.dataStore = dataStore
        self.makeStockDetail = makeStockDetail
        self.makeSearch = makeSearch
    }

    /// Arama alttan açılan bir sayfa (sheet), kendi navigation bar'ıyla (arama çubuğu orada).
    func routeToSearch() {
        let navigationController = UINavigationController(rootViewController: makeSearch())
        Theme.style(navigationController.navigationBar)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        viewController?.present(navigationController, animated: true)
    }

    /// Clean Swift'in iki adımı:
    /// 1. **DataPassing:** kaynak DataStore'dan oku → hedef DataStore'a yaz.
    /// 2. **Navigation:** hedef ekranı aç.
    func routeToStockDetail(symbol: Symbol) {
        guard let instrument = dataStore.instruments.first(where: { $0.symbol == symbol }) else { return }

        let destination = makeStockDetail()
        passData(instrument, to: destination.dataStore)
        viewController?.navigationController?.pushViewController(destination.viewController, animated: true)
    }

    private func passData(_ instrument: Instrument, to destination: StockDetailDataStore) {
        destination.instrument = instrument
        destination.initialQuote = dataStore.quotes[instrument.symbol]
    }
}
