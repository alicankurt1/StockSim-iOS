import UIKit
import Domain

@MainActor
protocol HoldingsRoutingLogic {
    func routeToStockDetail(symbol: Symbol)
}

/// Pozisyona dokununca hisse detayı açılır. Watchlist ile aynı detay sahnesi ve aynı
/// DataPassing: hisse + bilinen son fiyat hedef DataStore'a yazılır.
@MainActor
final class HoldingsRouter: HoldingsRoutingLogic {

    weak var viewController: UIViewController?
    let dataStore: HoldingsDataStore
    private let makeStockDetail: StockDetailFactory

    init(dataStore: HoldingsDataStore, makeStockDetail: @escaping StockDetailFactory) {
        self.dataStore = dataStore
        self.makeStockDetail = makeStockDetail
    }

    func routeToStockDetail(symbol: Symbol) {
        guard let instrument = dataStore.instrument(for: symbol) else { return }
        let destination = makeStockDetail()
        destination.dataStore.instrument = instrument
        destination.dataStore.initialQuote = dataStore.quote(for: symbol)
        viewController?.navigationController?.pushViewController(destination.viewController, animated: true)
    }
}
