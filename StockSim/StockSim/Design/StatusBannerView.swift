import UIKit

/// Ekranın altında (tab bar'ın üstünde) beliren küçük durum şeridi:
/// "Reconnecting… prices may be delayed", "Trading halted" gibi.
/// Generic: hangi ekran kullanırsa kullansın sadece metni verir; `nil` verince kaybolur.
final class StatusBannerView: UIView {

    private let iconView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surfaceElevated
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.warning.withAlphaComponent(0.4).cgColor
        alpha = 0
        isHidden = true
        isAccessibilityElement = true
        accessibilityTraits = .staticText

        iconView.tintColor = Theme.Color.warning
        iconView.preferredSymbolConfiguration = .init(pointSize: 13, weight: .semibold)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = Theme.Color.textPrimary
        label.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.spacing = Theme.Spacing.s
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Mesaj verince yumuşakça belirir, `nil` verince kaybolur.
    func show(_ message: String?) {
        let visible = message != nil
        if let message {
            label.text = message
            accessibilityLabel = message
        }
        guard visible != (alpha > 0) else { return }
        if visible {
            isHidden = false
            transform = CGAffineTransform(translationX: 0, y: 12)
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState]) {
            self.alpha = visible ? 1 : 0
            self.transform = .identity
        } completion: { _ in
            if !visible { self.isHidden = true }
        }
        if visible { UIAccessibility.post(notification: .announcement, argument: message) }
    }

    /// Bir ekranın altına, safe area'nın üstüne yerleştirir.
    func install(in view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: Theme.Spacing.l),
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Spacing.m),
        ])
    }
}
