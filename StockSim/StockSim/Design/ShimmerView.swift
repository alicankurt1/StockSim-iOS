import UIKit

/// Yüklenirken gösterilen gri kutu; üzerinden soldan sağa bir parıltı geçer.
/// Generic bileşen: herhangi bir ekranın skeleton'ında kullanılabilir.
///
/// Çizim Core Animation ile: bir `CAGradientLayer` (şeffaf → parlak → şeffaf)
/// kutunun içinde yatay olarak kaydırılıyor. Animasyon GPU'da çalışır, main thread'i yormaz.
final class ShimmerView: UIView {

    private let gradientLayer = CAGradientLayer()
    private static let animationKey = "shimmer"

    init(cornerRadius: CGFloat = Theme.Radius.pill) {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.skeleton
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations = [0, 0.5, 1]
        layer.addSublayer(gradientLayer)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Boyut değişince animasyonu yeni genişliğe göre yeniden kur.
        guard gradientLayer.frame.size != bounds.size else { return }
        gradientLayer.frame = bounds
        restartAnimation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Ekranda değilken animasyon boşuna çalışmasın.
        if window == nil {
            gradientLayer.removeAnimation(forKey: Self.animationKey)
        } else {
            restartAnimation()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CALayer `CGColor` kullanır ve açık/koyu mod değişimini kendisi takip etmez.
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        let highlight = Theme.Color.skeletonHighlight.resolvedColor(with: traitCollection)
        gradientLayer.colors = [
            highlight.withAlphaComponent(0).cgColor,
            highlight.cgColor,
            highlight.withAlphaComponent(0).cgColor,
        ]
    }

    private func restartAnimation() {
        guard window != nil, bounds.width > 0 else { return }
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 1.2
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(animation, forKey: Self.animationKey)
    }
}
