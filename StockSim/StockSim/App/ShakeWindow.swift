import UIKit

/// Sallama hareketini yakalayan pencere. Responder zincirinde kimse sallamayı
/// işlemezse olay en sonda pencereye gelir; debug menüsünü buradan açıyoruz.
/// Simülatörde: Device → Shake (⌃⌘Z).
final class ShakeWindow: UIWindow {

    var onShake: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
        super.motionEnded(motion, with: event)
    }
}
