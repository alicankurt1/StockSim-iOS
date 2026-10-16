import UIKit
import Domain

@MainActor
protocol StockDetailRoutingLogic {
    func routeToTradeTicket(side: OrderSide)
}

typealias TradeTicketFactory = @MainActor () -> (viewController: UIViewController, dataStore: TradeTicketDataStore)

@MainActor
final class StockDetailRouter: StockDetailRoutingLogic {

    weak var viewController: UIViewController?
    let dataStore: StockDetailDataStore
    private let makeTradeTicket: TradeTicketFactory

    init(dataStore: StockDetailDataStore, makeTradeTicket: @escaping TradeTicketFactory) {
        self.dataStore = dataStore
        self.makeTradeTicket = makeTradeTicket
    }

    /// Al/sat sayfası alttan açılır (sheet). Hisse ve taraf hedef DataStore'a yazılır.
    func routeToTradeTicket(side: OrderSide) {
        guard let instrument = dataStore.instrument else { return }
        let destination = makeTradeTicket()
        destination.dataStore.instrument = instrument
        destination.dataStore.side = side

        let navigationController = UINavigationController(rootViewController: destination.viewController)
        Theme.style(navigationController.navigationBar)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        viewController?.present(navigationController, animated: true)
    }
}
