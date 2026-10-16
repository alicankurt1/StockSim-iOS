import UIKit
import Charts

/// İzleme listesi kartı.
///
/// ```
/// ┌──────────────────────────────────────────────┐
/// │ (TH)  THYAO                       ₺287,50     │
/// │       Türk Hava Yolları          [+%1,14]     │
/// └──────────────────────────────────────────────┘
/// ```
/// İki hali var: veri (`configure(with:)`) ve yükleniyor (`showPlaceholder()`).
/// Hücreler yeniden kullanıldığı (reuse) için her `configure` tüm alanları baştan ayarlar.
final class WatchlistCell: UICollectionViewCell {

    private let monogramLabel = UILabel()
    private let symbolLabel = UILabel()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let changeLabel = PaddedLabel()
    private let sparklineView = SparklineView()

    private let contentStack = UIStackView()
    private let skeletonStack = UIStackView()

    /// Son gösterilen satır: fiyat değişti mi diye karşılaştırmak için.
    private var displayedRow: Watchlist.Row?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpCard()
        setUpContent()
        setUpSkeleton()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Dokunulurken kart hafifçe küçülür: basılma hissi.
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
                self.alpha = self.isHighlighted ? 0.85 : 1
            }
        }
    }

    // MARK: - Durumlar

    func configure(with row: Watchlist.Row) {
        contentStack.isHidden = false
        skeletonStack.isHidden = true

        // Aynı hisse ve fiyat değiştiyse kısa bir renk yanıp sönmesi (reconfigure sonrası).
        let priceChanged = displayedRow?.id == row.id && displayedRow?.price != row.price
        displayedRow = row

        monogramLabel.text = row.monogram
        symbolLabel.text = row.symbol
        nameLabel.text = row.name
        priceLabel.text = row.price
        changeLabel.text = row.change
        changeLabel.isHidden = row.change.isEmpty

        // Presenter'ın yön kararını (enum) renge burada çeviriyoruz: UIKit sadece View'da.
        let color = row.trend.color
        changeLabel.textColor = color
        changeLabel.backgroundColor = color.withAlphaComponent(0.15)
        sparklineView.setValues(row.sparkline, color: color)
        sparklineView.isHidden = row.sparkline.count < 2

        isAccessibilityElement = true
        accessibilityLabel = "\(row.symbol), \(row.name), \(row.price), \(row.change)"

        if priceChanged { flashPrice(color: color) }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Hücre başka bir hisseye verilecek: eski hissenin animasyonu taşınmasın.
        displayedRow = nil
        priceLabel.layer.removeAllAnimations()
        priceLabel.textColor = Theme.Color.textPrimary
    }

    /// Fiyat metni bir an yön renginde parlar, sonra normale döner.
    ///
    /// `textColor` UIView.animate ile animasyonlanamaz; bu yüzden cross-dissolve geçişi.
    /// Geçiş, başladığı andaki ÇİZİLMİŞ görüntüden başlar: yeni renk önce ekrana
    /// çizilsin diye geri dönüşü kısa bir gecikmeyle başlatıyoruz.
    private func flashPrice(color: UIColor) {
        priceLabel.textColor = color
        let rowID = displayedRow?.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            // Bu arada hücre başka bir hisseye verildiyse dokunma.
            guard let self, self.displayedRow?.id == rowID else { return }
            UIView.transition(with: self.priceLabel, duration: 0.5, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.priceLabel.textColor = Theme.Color.textPrimary
            }
        }
    }

    func showPlaceholder() {
        displayedRow = nil
        contentStack.isHidden = true
        skeletonStack.isHidden = false
        isAccessibilityElement = true
        accessibilityLabel = "Loading"
    }

    // MARK: - Kurulum

    private func setUpCard() {
        contentView.backgroundColor = Theme.Color.surface
        contentView.layer.cornerRadius = Theme.Radius.card
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = Theme.Color.border.cgColor
    }

    private func setUpContent() {
        monogramLabel.font = Theme.Font.monogram
        monogramLabel.textColor = Theme.Color.accent
        monogramLabel.textAlignment = .center
        monogramLabel.backgroundColor = Theme.Color.accent.withAlphaComponent(0.15)
        monogramLabel.layer.cornerRadius = 20
        monogramLabel.clipsToBounds = true

        symbolLabel.font = Theme.Font.symbol
        symbolLabel.textColor = Theme.Color.textPrimary
        nameLabel.font = Theme.Font.name
        nameLabel.textColor = Theme.Color.textSecondary

        priceLabel.font = Theme.Font.price
        priceLabel.textColor = Theme.Color.textPrimary
        changeLabel.font = Theme.Font.change
        changeLabel.layer.cornerRadius = Theme.Radius.pill
        changeLabel.clipsToBounds = true

        let titles = verticalStack([symbolLabel, nameLabel], alignment: .leading)
        let values = verticalStack([priceLabel, changeLabel], alignment: .trailing)
        // İsim uzunsa önce o kısalsın, fiyat hep tam görünsün.
        values.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentStack.addArrangedSubview(monogramLabel)
        contentStack.addArrangedSubview(titles)
        contentStack.addArrangedSubview(sparklineView)
        contentStack.addArrangedSubview(values)
        configureRowStack(contentStack)

        NSLayoutConstraint.activate([
            monogramLabel.widthAnchor.constraint(equalToConstant: 40),
            monogramLabel.heightAnchor.constraint(equalToConstant: 40),
            sparklineView.widthAnchor.constraint(equalToConstant: 64),
            sparklineView.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    /// Skeleton, gerçek içerikle aynı iskelete sahip: rozet, iki çubuk, grafik kutusu, iki çubuk.
    private func setUpSkeleton() {
        let monogram = ShimmerView(cornerRadius: 20)
        let left = verticalStack([shimmer(width: 64, height: 14), shimmer(width: 120, height: 11)], alignment: .leading)
        let right = verticalStack([shimmer(width: 72, height: 14), shimmer(width: 52, height: 18)], alignment: .trailing)

        skeletonStack.addArrangedSubview(monogram)
        skeletonStack.addArrangedSubview(left)
        skeletonStack.addArrangedSubview(shimmer(width: 64, height: 28))
        skeletonStack.addArrangedSubview(right)
        configureRowStack(skeletonStack)
        skeletonStack.isHidden = true

        NSLayoutConstraint.activate([
            monogram.widthAnchor.constraint(equalToConstant: 40),
            monogram.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    /// İçerik ve skeleton aynı yatay düzeni ve kenar boşluklarını paylaşır.
    private func configureRowStack(_ stack: UIStackView) {
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Theme.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        // Başlık sütunu boşluğu doldursun, sağdaki sütun sağa yaslansın.
        stack.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.arrangedSubviews.last?.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.l),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.l),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.m),
        ])
    }

    private func verticalStack(_ views: [UIView], alignment: UIStackView.Alignment) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = alignment
        stack.spacing = Theme.Spacing.xs
        return stack
    }

    private func shimmer(width: CGFloat, height: CGFloat) -> ShimmerView {
        let view = ShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: height),
        ])
        return view
    }

    // MARK: - Açık/koyu mod

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // `layer.borderColor` CGColor'dır; mod değişiminde kendiliğinden güncellenmez.
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            contentView.layer.borderColor = Theme.Color.border.resolvedColor(with: traitCollection).cgColor
        }
    }
}
