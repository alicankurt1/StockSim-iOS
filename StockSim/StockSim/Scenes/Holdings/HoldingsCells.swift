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

// MARK: - Pozisyon / işlem satırı

/// Pozisyon ve işlem satırları aynı iskeleti paylaşır: rozet · başlık/alt başlık · değer/etiket.
final class HoldingsRowCell: UICollectionViewCell {

    private let badgeLabel = UILabel()
    private let badgeIcon = UIImageView()
    private let badge = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let detailLabel = PaddedLabel()

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.alpha = self.isHighlighted ? 0.85 : 1
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        styleAsCard(contentView)

        badge.layer.cornerRadius = 20
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = Theme.Font.monogram
        badgeLabel.textAlignment = .center
        badgeIcon.contentMode = .center
        badgeIcon.preferredSymbolConfiguration = .init(pointSize: 15, weight: .bold)
        for view in [badgeLabel, badgeIcon] {
            view.translatesAutoresizingMaskIntoConstraints = false
            badge.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            ])
        }

        titleLabel.font = Theme.Font.symbol
        titleLabel.textColor = Theme.Color.textPrimary
        subtitleLabel.font = Theme.Font.name
        subtitleLabel.textColor = Theme.Color.textSecondary
        valueLabel.font = Theme.Font.price
        valueLabel.textColor = Theme.Color.textPrimary
        detailLabel.font = Theme.Font.change
        detailLabel.layer.cornerRadius = Theme.Radius.pill
        detailLabel.clipsToBounds = true

        let titles = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titles.axis = .vertical
        titles.spacing = Theme.Spacing.xs
        titles.setContentHuggingPriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let values = UIStackView(arrangedSubviews: [valueLabel, detailLabel])
        values.axis = .vertical
        values.alignment = .trailing
        values.spacing = Theme.Spacing.xs
        values.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [badge, titles, values])
        row.alignment = .center
        row.spacing = Theme.Spacing.m
        pin(row, in: contentView, insets: Theme.Spacing.m)
        row.layoutMargins = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        row.isLayoutMarginsRelativeArrangement = true

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 40),
            badge.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with row: Holdings.PositionRow) {
        showBadge(text: row.monogram, icon: nil, color: Theme.Color.accent)
        titleLabel.text = row.symbol
        subtitleLabel.text = row.summary
        valueLabel.text = row.value
        detailLabel.isHidden = false
        detailLabel.text = row.profitLoss
        detailLabel.textColor = row.trend.color
        detailLabel.backgroundColor = row.trend.color.withAlphaComponent(0.15)
        accessibilityLabel = "\(row.symbol), \(row.summary), \(row.value), \(row.profitLoss)"
    }

    func configure(with row: Holdings.ActivityRow) {
        let isBuy = row.side == .buy
        showBadge(text: nil, icon: isBuy ? "arrow.down.left" : "arrow.up.right", color: isBuy ? Theme.Color.up : Theme.Color.down)
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        valueLabel.text = row.amount
        detailLabel.isHidden = true
        accessibilityLabel = "\(row.title), \(row.subtitle), \(row.amount)"
    }

    private func showBadge(text: String?, icon: String?, color: UIColor) {
        badge.backgroundColor = color.withAlphaComponent(0.15)
        badgeLabel.text = text
        badgeLabel.textColor = color
        badgeLabel.isHidden = text == nil
        badgeIcon.image = icon.flatMap { UIImage(systemName: $0) }
        badgeIcon.tintColor = color
        badgeIcon.isHidden = icon == nil
        isAccessibilityElement = true
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
