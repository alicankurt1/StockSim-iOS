import UIKit

/// Kart görünümlü genel satır: rozet · başlık/alt başlık · değer/etiket.
/// Portföydeki pozisyon ve işlem satırları ile What If senaryoları bunu kullanır (tekrar yok).
///
/// `UICollectionViewListCell`: liste düzeninde kaydırarak silmeyi destekler; diğer
/// düzenlerde de normal hücre gibi çalışır. Kart, kartlar arası boşluk kalsın diye içteki
/// `card` view'ında.
final class CardRowCell: UICollectionViewListCell {

    /// Satırın görünüm modeli (View katmanında: renk burada `UIColor`).
    struct Content {
        enum Badge {
            case text(String)
            case symbol(String)
        }

        var badge: Badge
        var badgeColor: UIColor
        var title: String
        var subtitle: String
        var value: String
        /// Değerin altındaki renkli etiket (ör. K/Z); `nil` ise gizli.
        var detail: String?
        var detailColor: UIColor = Theme.Color.textSecondary
    }

    private let card = UIView()
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
                self.card.alpha = self.isHighlighted ? 0.85 : 1
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundConfiguration = .clear()
        setUpCard()
        setUpContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with content: Content) {
        badge.backgroundColor = content.badgeColor.withAlphaComponent(0.15)
        switch content.badge {
        case let .text(text):
            badgeLabel.text = text
            badgeIcon.image = nil
        case let .symbol(name):
            badgeLabel.text = nil
            badgeIcon.image = UIImage(systemName: name)
        }
        badgeLabel.textColor = content.badgeColor
        badgeIcon.tintColor = content.badgeColor
        badgeLabel.isHidden = badgeLabel.text == nil
        badgeIcon.isHidden = badgeIcon.image == nil

        titleLabel.text = content.title
        subtitleLabel.text = content.subtitle
        valueLabel.text = content.value
        detailLabel.isHidden = content.detail == nil
        detailLabel.text = content.detail
        detailLabel.textColor = content.detailColor
        detailLabel.setRoundedBackground(content.detailColor.withAlphaComponent(0.15), cornerRadius: Theme.Radius.pill)

        isAccessibilityElement = true
        accessibilityLabel = [content.title, content.subtitle, content.value, content.detail].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: - Kurulum

    private func setUpCard() {
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.Color.border.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    private func setUpContent() {
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

        let titles = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titles.axis = .vertical
        titles.spacing = Theme.Spacing.xs

        let values = UIStackView(arrangedSubviews: [valueLabel, detailLabel])
        values.axis = .vertical
        values.alignment = .trailing
        values.spacing = Theme.Spacing.xs

        // Boşluğu her zaman başlık etiketleri alsın (WatchlistCell'deki dersin aynısı):
        // etiket öncelikleri + sağdaki sütunu "olabildiğince dar" tutan düşük öncelikli kural.
        [titleLabel, subtitleLabel].forEach { $0.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal) }
        [valueLabel, detailLabel].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let hugValues = values.widthAnchor.constraint(equalToConstant: 0)
        hugValues.priority = .fittingSizeLevel
        hugValues.isActive = true

        let row = UIStackView(arrangedSubviews: [badge, titles, values])
        row.alignment = .center
        row.spacing = Theme.Spacing.m
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.m),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Theme.Spacing.m),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.l),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.l),
            badge.widthAnchor.constraint(equalToConstant: 40),
            badge.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            card.layer.borderColor = Theme.Color.border.resolvedColor(with: traitCollection).cgColor
        }
    }
}
