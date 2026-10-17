import UIKit

@MainActor
protocol StockSearchRoutingLogic {
    func dismiss()
}

@MainActor
final class StockSearchRouter: StockSearchRoutingLogic {

    weak var viewController: UIViewController?

    func dismiss() {
        viewController?.dismiss(animated: true)
    }
}
