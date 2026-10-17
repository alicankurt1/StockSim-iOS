import UIKit

/// "Bir sonraki ekran karesinde çalıştır." `CADisplayLink` ekran yenilenmeden hemen önce
/// tetiklenir; iş yoksa duraklatılır (boşuna her karede uyanmasın).
///
/// `maximumFramesPerSecond`: liste güncellemesi için 120 Hz gereksiz; 30 kare/sn göz için
/// yeterince akıcı ve işlemciye yarısından az iş düşer.
@MainActor
final class FrameScheduler {

    private var displayLink: CADisplayLink?
    private var blocks: [@MainActor () -> Void] = []
    private let maximumFramesPerSecond: Float

    init(maximumFramesPerSecond: Float = 30) {
        self.maximumFramesPerSecond = maximumFramesPerSecond
    }

    func schedule(_ block: @escaping @MainActor () -> Void) {
        blocks.append(block)
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: maximumFramesPerSecond, preferred: maximumFramesPerSecond)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        displayLink?.isPaused = false
    }

    @objc private func tick() {
        let current = blocks
        blocks.removeAll()
        displayLink?.isPaused = true
        current.forEach { $0() }
    }

    func invalidate() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
