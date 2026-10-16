import UIKit

@MainActor
protocol TradeTicketRoutingLogic {
    func dismiss()
}

@MainActor
final class TradeTicketRouter: TradeTicketRoutingLogic {

    weak var viewController: UIViewController?

    func dismiss() {
        viewController?.dismiss(animated: true)
    }
}
