import UIKit

/// Phase 7'de al/sat ekranına geçiş buraya gelecek.
@MainActor
protocol StockDetailRoutingLogic {}

@MainActor
final class StockDetailRouter: StockDetailRoutingLogic {

    weak var viewController: UIViewController?
    let dataStore: StockDetailDataStore

    init(dataStore: StockDetailDataStore) {
        self.dataStore = dataStore
    }
}
