import UIKit

/// "Hakkında" ekranının içeriği. UIKit'ten bağımsız, saf veri: metinler test edilebilir.
struct AboutContent: Equatable {
    struct Section: Equatable {
        let icon: String
        let title: String
        let body: String
    }

    let sections: [Section]
    let footer: String

    static func make(version: String, build: String, isDistribution: Bool) -> AboutContent {
        let market = isDistribution
            ? "Prices are generated on your device by a random market simulator. All companies are fictional; any resemblance to real companies is coincidental."
            : "Prices come from an on-device market simulator, or from delayed real data in developer builds. Simulated prices have nothing to do with the real market."
        return AboutContent(
            sections: [
                Section(icon: "graduationcap", title: "A learning project",
                        body: "StockSim is a paper-trading simulator built to practise iOS development. You trade with a virtual ₺100,000 account. No real money, no real orders."),
                Section(icon: "waveform.path.ecg", title: "Simulated market", body: market),
                Section(icon: "exclamationmark.shield", title: "Not investment advice",
                        body: "Nothing in this app is financial or investment advice. What If results are hypothetical and based on simulated prices."),
                Section(icon: "lock.shield", title: "Your privacy",
                        body: "No account, no tracking, no analytics. The app collects no data; your portfolio and lists stay on this device."),
                Section(icon: "chevron.left.forwardslash.chevron.right", title: "Open source",
                        body: "The source code is available on GitHub under the MIT license. No third-party code is included."),
            ],
            footer: "Version \(version) (\(build))"
        )
    }
}

/// Statik bilgi ekranı. İş kuralı yok, bu yüzden VIP katmanlarına bölünmedi (KISS):
/// içerik dışarıdan `AboutContent` olarak gelir, ekran sadece onu çizer.
@MainActor
final class AboutViewController: UIViewController {

    private let content: AboutContent
    private let isFirstLaunch: Bool
    private let repositoryURL: URL

    init(content: AboutContent, isFirstLaunch: Bool, repositoryURL: URL) {
        self.content = content
        self.isFirstLaunch = isFirstLaunch
        self.repositoryURL = repositoryURL
        super.init(nibName: nil, bundle: nil)
        title = "About StockSim"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        if !isFirstLaunch {
            navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            })
        }

        let stack = UIStackView(arrangedSubviews: content.sections.map(makeCard))
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.m

        stack.addArrangedSubview(makeButton(
            title: "View source on GitHub", filled: false,
            action: UIAction { [repositoryURL] _ in UIApplication.shared.open(repositoryURL) }
        ))
        if isFirstLaunch {
            stack.addArrangedSubview(makeButton(
                title: "Got it", filled: true,
                action: UIAction { [weak self] _ in self?.dismiss(animated: true) }
            ))
        }

        let footer = UILabel()
        footer.text = content.footer
        footer.font = Theme.Font.scaled(.systemFont(ofSize: 12), style: .caption1)
        footer.textColor = Theme.Color.textSecondary
        footer.textAlignment = .center
        stack.addArrangedSubview(footer)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let margin = Theme.Spacing.l
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: margin),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -margin),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: margin),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -margin),
        ])
    }

    /// İkon + başlık + metin kartı. Metin Dynamic Type ile büyür, satır sınırı yok.
    private func makeCard(_ section: AboutContent.Section) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: section.icon))
        icon.tintColor = Theme.Color.accent
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let title = UILabel()
        title.text = section.title
        title.font = Theme.Font.symbol
        title.textColor = Theme.Color.textPrimary
        title.adjustsFontForContentSizeCategory = true

        let body = UILabel()
        body.text = section.body
        body.font = Theme.Font.name
        body.textColor = Theme.Color.textSecondary
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true

        let texts = UIStackView(arrangedSubviews: [title, body])
        texts.axis = .vertical
        texts.spacing = Theme.Spacing.xs

        let row = UIStackView(arrangedSubviews: [icon, texts])
        row.alignment = .top
        row.spacing = Theme.Spacing.m
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        row.backgroundColor = Theme.Color.surface
        row.layer.cornerRadius = Theme.Radius.card
        row.layer.borderWidth = 1
        row.layer.borderColor = Theme.Color.border.cgColor
        // VoiceOver kartı tek parça okusun.
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(section.title). \(section.body)"
        return row
    }

    private func makeButton(title: String, filled: Bool, action: UIAction) -> UIButton {
        var configuration: UIButton.Configuration = filled ? .filled() : .tinted()
        configuration.title = title
        configuration.cornerStyle = .large
        configuration.buttonSize = .large
        let button = UIButton(configuration: configuration, primaryAction: action)
        return button
    }
}
