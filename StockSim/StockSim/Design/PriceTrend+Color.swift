import UIKit

extension PriceTrend {
    /// Yönün rengi. Bu eşleme View katmanında; Presenter sadece yönü bilir.
    var color: UIColor {
        switch self {
        case .up: Theme.Color.up
        case .down: Theme.Color.down
        case .flat: Theme.Color.textSecondary
        }
    }
}
