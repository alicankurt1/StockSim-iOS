import UIKit
import Domain
import Charts

@MainActor
protocol WhatIfBuilderDisplayLogic: AnyObject {
    func displayBuilder(viewModel: WhatIfBuilder.ViewModel)
    func displayTracked()
}

/// Senaryo oluşturucu: hisse, tutar, tarih → sonuç kartı ve grafik.
final class WhatIfBuilderViewController: UIViewController {

    private let interactor: WhatIfBuilderBusinessLogic
    private let router: WhatIfBuilderRoutingLogic

    private let stockButton = UIButton(type: .system)
    private let amountField = UITextField()
    private let datePicker = UIDatePicker()

    private let resultCard = UIView()
    private let entryLabel = UILabel()
    private let valueLabel = UILabel()
    private let profitLossLabel = UILabel()
    private let chartView = ChartView()
    private let messageLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let trackButton = UIButton(type: .system)

    init(interactor: WhatIfBuilderBusinessLogic, router: WhatIfBuilderRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
        title = "What If"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.router.dismiss()
        })
        setUpLayout()
        Task { await interactor.load() }
    }

    // MARK: - Kullanıcı olayları (hepsi Interactor'a)

    @objc private func amountChanged() {
        Task { await interactor.edit(request: .init(amountText: amountField.text ?? "")) }
    }

    @objc private func dateChanged() {
        Task { await interactor.edit(request: .init(date: datePicker.date)) }
    }

    @objc private func trackTapped() {
        Task { await interactor.track() }
    }

    // MARK: - Yerleşim

    private func setUpLayout() {
        var stockConfiguration = UIButton.Configuration.tinted()
        stockConfiguration.baseForegroundColor = Theme.Color.accent
        stockConfiguration.image = UIImage(systemName: "chevron.up.chevron.down")
        stockConfiguration.imagePlacement = .trailing
        stockConfiguration.imagePadding = Theme.Spacing.s
        stockConfiguration.cornerStyle = .medium
        stockButton.configuration = stockConfiguration
        stockButton.showsMenuAsPrimaryAction = true

        amountField.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        amountField.textColor = Theme.Color.textPrimary
        amountField.keyboardType = .decimalPad
        amountField.textAlignment = .right
        amountField.text = "100.000"
        amountField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        let currency = UILabel()
        currency.text = "₺ "
        currency.textColor = Theme.Color.textSecondary
        amountField.leftView = currency
        amountField.leftViewMode = .always

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.tintColor = Theme.Color.accent
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        let form = UIStackView(arrangedSubviews: [
            row("Stock", stockButton), row("Amount", amountField), row("Bought on", datePicker),
        ])
        form.axis = .vertical
        form.spacing = Theme.Spacing.l
        let formCard = card(form)

        entryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        entryLabel.textColor = Theme.Color.textSecondary
        entryLabel.numberOfLines = 0
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 30, weight: .bold)
        valueLabel.textColor = Theme.Color.textPrimary
        valueLabel.adjustsFontSizeToFitWidth = true
        profitLossLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        chartView.gridColor = Theme.Color.border
        chartView.backgroundColor = Theme.Color.surface
        chartView.heightAnchor.constraint(equalToConstant: 170).isActive = true
        let result = UIStackView(arrangedSubviews: [entryLabel, valueLabel, profitLossLabel, chartView])
        result.axis = .vertical
        result.spacing = Theme.Spacing.xs
        result.setCustomSpacing(Theme.Spacing.m, after: profitLossLabel)
        let resultContainer = card(result)
        resultContainer.addSubview(spinner)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = Theme.Color.textSecondary
        NSLayoutConstraint.activate([
            spinner.topAnchor.constraint(equalTo: resultContainer.topAnchor, constant: Theme.Spacing.l),
            spinner.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -Theme.Spacing.l),
        ])
        resultCardContainer = resultContainer

        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textColor = Theme.Color.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var trackConfiguration = UIButton.Configuration.filled()
        trackConfiguration.title = "Track this"
        trackConfiguration.baseBackgroundColor = Theme.Color.accent
        trackConfiguration.cornerStyle = .large
        trackConfiguration.buttonSize = .large
        trackButton.configuration = trackConfiguration
        trackButton.addTarget(self, action: #selector(trackTapped), for: .touchUpInside)

        let disclaimer = UILabel()
        disclaimer.text = "Hypothetical result. Not investment advice."
        disclaimer.font = .systemFont(ofSize: 11)
        disclaimer.textColor = Theme.Color.textSecondary
        disclaimer.textAlignment = .center

        let content = UIStackView(arrangedSubviews: [formCard, resultContainer, messageLabel, trackButton, disclaimer])
        content.axis = .vertical
        content.spacing = Theme.Spacing.l
        content.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .onDrag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.Spacing.l),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.Spacing.l),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Theme.Spacing.l),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Theme.Spacing.l),
        ])
    }

    private var resultCardContainer: UIView?
    /// Son çizilen grafik: sadece veri değişince (hisse/tarih) animasyon, tutar yazarken değil.
    private var drawnChart: [Double] = []

    private func row(_ title: String, _ control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = Theme.Color.textSecondary
        label.setContentHuggingPriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.alignment = .center
        stack.spacing = Theme.Spacing.m
        return stack
    }

    private func card(_ content: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.Color.border.cgColor
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.l),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Theme.Spacing.l),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.l),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.l),
        ])
        return card
    }
}

// MARK: - WhatIfBuilderDisplayLogic

extension WhatIfBuilderViewController: WhatIfBuilderDisplayLogic {

    func displayBuilder(viewModel: WhatIfBuilder.ViewModel) {
        title = viewModel.title
        trackButton.configuration?.title = viewModel.trackTitle
        // Kullanıcı yazarken alanı ezme; sadece dışarıdan değiştiğinde (ör. düzenleme açılışı).
        if !amountField.isFirstResponder { amountField.text = viewModel.amountText }
        stockButton.configuration?.title = viewModel.stockTitle
        stockButton.menu = UIMenu(children: viewModel.stockOptions.map { option in
            UIAction(title: option.title, state: option.isSelected ? .on : .off) { [interactor] _ in
                Task { await interactor.edit(request: .init(instrument: option.instrument)) }
            }
        })
        datePicker.minimumDate = viewModel.dateRange.lowerBound
        datePicker.maximumDate = viewModel.dateRange.upperBound
        if datePicker.date != viewModel.date { datePicker.date = viewModel.date }

        viewModel.isCalculating ? spinner.startAnimating() : spinner.stopAnimating()
        trackButton.isEnabled = viewModel.isTrackEnabled

        if let result = viewModel.result {
            resultCardContainer?.isHidden = false
            entryLabel.text = result.entry
            valueLabel.text = result.value
            profitLossLabel.text = result.profitLoss
            profitLossLabel.textColor = result.trend.color
            let points = result.chart.map { ChartPoint(open: $0, high: $0, low: $0, close: $0) }
            chartView.setData(
                ChartData(points: points, baseline: result.baseline),
                lineColor: result.trend.color,
                animated: result.chart.count != drawnChart.count || result.chart.first != drawnChart.first
            )
            drawnChart = result.chart
        } else if !viewModel.isCalculating {
            // Hesap sürerken eski sonucu göster (titremesin); hata/eksik bilgide gizle.
            resultCardContainer?.isHidden = true
        }
        messageLabel.text = viewModel.message
        messageLabel.isHidden = viewModel.message == nil
    }

    func displayTracked() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        router.dismiss()
    }
}
