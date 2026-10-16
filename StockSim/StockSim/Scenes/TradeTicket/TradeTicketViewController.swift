import UIKit
import Domain

@MainActor
protocol TradeTicketDisplayLogic: AnyObject {
    func displayForm(viewModel: TradeTicket.FormViewModel)
    func displayTradeCompleted(viewModel: TradeTicket.Submit.ViewModel)
}

/// Al/sat formu (alttan açılan sayfa).
///
/// ```
///  [  Buy  |  Sell  ]
///  Market price          ₺287,50
///  Quantity          [–]  10  [+]
///  Estimated total     ₺2.875,00
///  Cash available ₺100.000,00
///  ⚠︎ Not enough cash…
///  [        Buy 10 shares        ]
/// ```
final class TradeTicketViewController: UIViewController {

    private let interactor: TradeTicketBusinessLogic
    private let router: TradeTicketRoutingLogic

    private let sideControl = UISegmentedControl(items: ["Buy", "Sell"])
    private let priceValueLabel = UILabel()
    private let quantityField = UITextField()
    private let totalValueLabel = UILabel()
    private let availabilityLabel = UILabel()
    private let errorLabel = UILabel()
    private let submitButton = UIButton(type: .system)
    private let formStack = UIStackView()
    private let successLabel = UILabel()

    private var liveUpdatesTask: Task<Void, Never>?
    private var currentQuantity = 1

    init(interactor: TradeTicketBusinessLogic, router: TradeTicketRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.router.dismiss()
        })
        setUpLayout()

        liveUpdatesTask = Task { [interactor] in
            await interactor.load(request: .init())
            await interactor.startLiveUpdates()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        liveUpdatesTask?.cancel()
    }

    // MARK: - Kullanıcı olayları (hepsi Interactor'a iletilir)

    @objc private func sideChanged() {
        interactor.edit(request: .init(side: sideControl.selectedSegmentIndex == 0 ? .buy : .sell))
    }

    @objc private func quantityChanged() {
        currentQuantity = Int(quantityField.text ?? "") ?? 0
        interactor.edit(request: .init(quantity: currentQuantity))
    }

    private func stepQuantity(by delta: Int) {
        currentQuantity = max(currentQuantity + delta, 0)
        interactor.edit(request: .init(quantity: currentQuantity))
    }

    @objc private func submitTapped() {
        view.endEditing(true)
        Task { await interactor.submit(request: .init()) }
    }

    // MARK: - Yerleşim

    private func setUpLayout() {
        sideControl.selectedSegmentTintColor = Theme.Color.accent
        sideControl.backgroundColor = Theme.Color.surfaceElevated
        sideControl.setTitleTextAttributes([.foregroundColor: Theme.Color.textSecondary], for: .normal)
        sideControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        sideControl.addTarget(self, action: #selector(sideChanged), for: .valueChanged)

        [priceValueLabel, totalValueLabel].forEach {
            $0.font = Theme.Font.price
            $0.textColor = Theme.Color.textPrimary
            $0.textAlignment = .right
        }

        quantityField.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        quantityField.textColor = Theme.Color.textPrimary
        quantityField.textAlignment = .center
        quantityField.keyboardType = .numberPad
        quantityField.backgroundColor = Theme.Color.surfaceElevated
        quantityField.layer.cornerRadius = Theme.Radius.pill
        quantityField.addTarget(self, action: #selector(quantityChanged), for: .editingChanged)
        quantityField.widthAnchor.constraint(equalToConstant: 72).isActive = true
        quantityField.heightAnchor.constraint(equalToConstant: 40).isActive = true

        availabilityLabel.font = .systemFont(ofSize: 13, weight: .medium)
        availabilityLabel.textColor = Theme.Color.textSecondary

        errorLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        errorLabel.textColor = Theme.Color.down
        errorLabel.numberOfLines = 0

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.baseBackgroundColor = Theme.Color.accent
        buttonConfiguration.cornerStyle = .large
        buttonConfiguration.buttonSize = .large
        submitButton.configuration = buttonConfiguration
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        let quantityControl = UIStackView(arrangedSubviews: [
            stepButton(symbol: "minus", delta: -1), quantityField, stepButton(symbol: "plus", delta: 1),
        ])
        quantityControl.spacing = Theme.Spacing.s
        quantityControl.alignment = .center

        let card = UIStackView(arrangedSubviews: [
            row(title: "Market price", value: priceValueLabel),
            row(title: "Quantity", value: quantityControl),
            row(title: "Estimated total", value: totalValueLabel),
        ])
        card.axis = .vertical
        card.spacing = Theme.Spacing.l
        card.isLayoutMarginsRelativeArrangement = true
        card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card

        [sideControl, card, availabilityLabel, errorLabel, submitButton].forEach(formStack.addArrangedSubview)
        formStack.axis = .vertical
        formStack.spacing = Theme.Spacing.l
        formStack.setCustomSpacing(Theme.Spacing.s, after: availabilityLabel)

        successLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        successLabel.textColor = Theme.Color.textPrimary
        successLabel.numberOfLines = 0
        successLabel.textAlignment = .center
        successLabel.isHidden = true

        let content = UIStackView(arrangedSubviews: [formStack, successLabel])
        content.axis = .vertical
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Spacing.l),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Spacing.l),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Spacing.l),
        ])
    }

    private func row(title: String, value: UIView) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = Theme.Color.textSecondary
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, value])
        stack.alignment = .center
        return stack
    }

    private func stepButton(symbol: String, delta: Int) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.image = UIImage(systemName: symbol)
        configuration.baseForegroundColor = Theme.Color.accent
        configuration.cornerStyle = .medium
        return UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.stepQuantity(by: delta)
        })
    }
}

// MARK: - TradeTicketDisplayLogic

extension TradeTicketViewController: TradeTicketDisplayLogic {

    func displayForm(viewModel: TradeTicket.FormViewModel) {
        title = viewModel.title
        sideControl.selectedSegmentIndex = viewModel.selectedSideIndex
        sideControl.setEnabled(viewModel.isSellEnabled, forSegmentAt: 1)
        priceValueLabel.text = viewModel.price
        // Kullanıcı yazarken imleci bozmayalım; sadece farklıysa güncelle.
        if quantityField.text != viewModel.quantityText { quantityField.text = viewModel.quantityText }
        totalValueLabel.text = viewModel.estimatedTotal
        availabilityLabel.text = viewModel.availability
        errorLabel.text = viewModel.errorMessage
        errorLabel.isHidden = viewModel.errorMessage == nil
        submitButton.configuration?.title = viewModel.submitTitle
        submitButton.isEnabled = viewModel.isSubmitEnabled
    }

    func displayTradeCompleted(viewModel: TradeTicket.Submit.ViewModel) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        formStack.isHidden = true
        successLabel.text = "✓\n\(viewModel.message)"
        successLabel.isHidden = false
        // Kısa bir onaydan sonra kapan.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            self?.router.dismiss()
        }
    }
}
