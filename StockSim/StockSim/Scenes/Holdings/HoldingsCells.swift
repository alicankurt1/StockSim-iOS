import UIKit
import Domain

// Portföy ekranının hücreleri. Hepsi Theme'deki kart görünümünü kullanır.

/// Temanın kart görünümü (lacivert zemin, yuvarlak köşe, ince kenarlık).
private func styleAsCard(_ view: UIView) {
    view.backgroundColor = Theme.Color.surface
    view.layer.cornerRadius = Theme.Radius.card
    view.layer.cornerCurve = .continuous
    view.layer.borderWidth = 1
    view.layer.borderColor = Theme.Color.border.cgColor
}

private func pin(_ content: UIView, in container: UIView, insets: CGFloat = Theme.Spacing.l) {
    content.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(content)
    NSLayoutConstraint.activate([
        content.topAnchor.constraint(equalTo: container.topAnchor, constant: insets),
        content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -insets),
        content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: insets),
        content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -insets),
    ])
}

// MARK: - Hesap kartı

final class AccountCardCell: UICollectionViewCell {

    private let totalValueLabel = UILabel()
    private let profitLossLabel = UILabel()
    private let cashValueLabel = UILabel()
    private let investedValueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        styleAsCard(contentView)

        let title = Self.caption("Total value")
        totalValueLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        totalValueLabel.textColor = Theme.Color.textPrimary
        totalValueLabel.adjustsFontSizeToFitWidth = true
        profitLossLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)

        let stats = UIStackView(arrangedSubviews: [
            Self.stat("Cash", value: cashValueLabel),
            Self.stat("Invested", value: investedValueLabel),
        ])
        stats.distribution = .fillEqually
        stats.spacing = Theme.Spacing.m

        let stack = UIStackView(arrangedSubviews: [title, totalValueLabel, profitLossLabel, stats])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.xs
        stack.setCustomSpacing(Theme.Spacing.l, after: profitLossLabel)
        pin(stack, in: contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with card: Holdings.AccountCard) {
        totalValueLabel.text = card.totalValue
        profitLossLabel.text = "\(card.totalProfitLoss) all time"
        profitLossLabel.textColor = card.trend.color
        cashValueLabel.text = card.cash
        investedValueLabel.text = card.invested
    }

    private static func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = Theme.Color.textSecondary
        return label
    }

    private static func stat(_ title: String, value: UILabel) -> UIView {
        value.font = Theme.Font.price
        value.textColor = Theme.Color.textPrimary
        value.adjustsFontSizeToFitWidth = true
        let stack = UIStackView(arrangedSubviews: [caption(title), value])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }
}

// MARK: - Boş durum

final class HoldingsEmptyCell: UICollectionViewCell {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        styleAsCard(contentView)
        contentView.layer.borderColor = UIColor.clear.cgColor
        contentView.backgroundColor = Theme.Color.surface.withAlphaComponent(0.5)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = Theme.Color.textSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        pin(label, in: contentView, insets: Theme.Spacing.l + 4)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(message: String) {
        label.text = message
    }
}

// MARK: - Bölüm başlığı

final class HoldingsSectionHeader: UICollectionReusableView {

    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = Theme.Color.textPrimary
        pin(label, in: self, insets: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
