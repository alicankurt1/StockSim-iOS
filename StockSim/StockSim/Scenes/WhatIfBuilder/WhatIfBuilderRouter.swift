import UIKit

@MainActor
protocol WhatIfBuilderRoutingLogic {
    func dismiss()
}

@MainActor
final class WhatIfBuilderRouter: WhatIfBuilderRoutingLogic {

    weak var viewController: UIViewController?

    func dismiss() {
        viewController?.dismiss(animated: true)
    }
}
