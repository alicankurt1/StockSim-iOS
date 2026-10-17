import UIKit
import Domain
import Charts

@MainActor
protocol StockDetailDisplayLogic: AnyObject {
    func displayInitial(viewModel: StockDetail.Initial.ViewModel)
    func displayMarketStatus(viewModel: StockDetail.MarketStatus.ViewModel)
    func displayHolding(viewModel: StockDetail.Holding.ViewModel)
    func displayDetail(viewModel: StockDetail.Load.ViewModel)
    func displayQuoteUpdate(viewModel: StockDetail.Update.ViewModel)
    func displayLoadError(message: String)
    func displaySelection(viewModel: StockDetail.Select.ViewModel)
}

/// Hisse detayı: büyük fiyat, çizgi grafik, aralık seçici, en yüksek/en düşük.
///
/// ```
///  Türk Hava Yolları
///  ₺287,50   [+%1,14]
/// ┌──────────────────────────┐
/// │        ╱╲    ╱‾‾         │  grafik
/// │ - - -╱- -╲╱- - - - - - - │  önceki kapanış
/// │  [1D] 1W  1M  1Y         │  aralık seçici
/// │  +%0,84 · Today          │
/// └──────────────────────────┘
///  High ₺289,10   Low ₺284,20
/// ```
final class StockDetailViewController: UIViewController {

    private let interactor: StockDetailBusinessLogic
    private let router: StockDetailRoutingLogic

    private let scrollView = UIScrollView()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let dayChangeLabel = PaddedLabel()
    private let chartView = ChartView()
    /// Çizgi / mum seçimi: sadece görünüm tercihi, iş kuralı değil → VC'de kalabilir.
    private let styleControl = UISegmentedControl(items: [
        UIImage(systemName: "chart.xyaxis.line") as Any,
        UIImage(systemName: "chart.bar.fill") as Any,
    ])
    private let rangeControl = UISegmentedControl()
    private let rangeChangeLabel = UILabel()
    private let highValueLabel = UILabel()
    private let lowValueLabel = UILabel()
    private let statusBanner = StatusBannerView()
    private let buyButton = UIButton(type: .system)
    private let sellButton = UIButton(type: .system)

    private let positionSummaryLabel = UILabel()
    private let positionValueLabel = UILabel()
    private let positionProfitLabel = UILabel()

    private var hasLoaded = false
    /// Pozisyon kartının dış kabı (gizle/göster).
    private var positionCardContainer: UIView?
    /// Parmak grafikteyken başlık seçili noktayı gösterir; canlı fiyat başlığı ezmesin.
    private var isScrubbing = false
    private var liveUpdatesTask: Task<Void, Never>?

    init(interactor: StockDetailBusinessLogic, router: StockDetailRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        setUpLayout()
        setUpStyleControl()
        statusBanner.install(in: view)
        // Ekran kayarak gelirken başlık dolu olsun: async yükleme beklenmeden, senkron.
        interactor.prepare()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        liveUpdatesTask = Task { [weak self, interactor] in
            if self?.hasLoaded == false {
                await interactor.load(request: .init(range: .day))
                self?.hasLoaded = true
            }
            await interactor.startLiveUpdates(request: .init())
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        liveUpdatesTask?.cancel()
        liveUpdatesTask = nil
    }

    // MARK: - Kullanıcı olayları

    @objc private func rangeChanged() {
        let index = rangeControl.selectedSegmentIndex
        guard ChartRange.allCases.indices.contains(index) else { return }
        // VC karar vermez, sadece iletir: VC → Interactor.
        Task { await interactor.load(request: .init(range: ChartRange.allCases[index])) }
    }

    @objc private func styleChanged() {
        // OCP: ChartView'a yeni bir çizer vermek yeterli; ChartView'ın içi değişmiyor.
        chartView.renderer = styleControl.selectedSegmentIndex == 0 ? LineChartRenderer() : CandlestickChartRenderer()
    }

    private func chartSelectionChanged(_ index: Int?) {
        isScrubbing = index != nil
        interactor.selectPoint(request: .init(index: index))
    }

    // MARK: - Yerleşim

    private func setUpStyleControl() {
        styleControl.selectedSegmentIndex = 0
        styleControl.selectedSegmentTintColor = Theme.Color.accent
        styleControl.backgroundColor = Theme.Color.surfaceElevated
        styleControl.addTarget(self, action: #selector(styleChanged), for: .valueChanged)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: styleControl)
    }

    private func setUpLayout() {
        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = Theme.Color.textSecondary

        priceLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        priceLabel.textColor = Theme.Color.textPrimary
        priceLabel.adjustsFontSizeToFitWidth = true

        dayChangeLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        dayChangeLabel.insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        dayChangeLabel.layer.cornerRadius = Theme.Radius.pill
        dayChangeLabel.clipsToBounds = true

        let priceRow = UIStackView(arrangedSubviews: [priceLabel, dayChangeLabel, UIView()])
        priceRow.alignment = .center
        priceRow.spacing = Theme.Spacing.m

        let header = UIStackView(arrangedSubviews: [nameLabel, priceRow])
        header.axis = .vertical
        header.spacing = Theme.Spacing.xs

        let content = UIStackView(arrangedSubviews: [header, makeChartCard(), makePositionCard(), makeStatsRow(), makeTradeButtons()])
        content.axis = .vertical
        content.spacing = Theme.Spacing.l
        content.translatesAutoresizingMaskIntoConstraints = false

        scrollView.alwaysBounceVertical = true
        // Üst boşluğu UIKit'in otomatik ayarına bırakmıyoruz: büyük başlıklı listeden gelirken
        // bar yüksekliği değişir ve otomatik ayar geç gelir → içerik zıplar. Safe area'ya sabitliyoruz.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(content)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Otomatik ayar kapalı olduğu için alt kenarı da (ana ekran çubuğu) safe area'ya sabitliyoruz.
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // İçerik, kaydırma alanının içinde; genişliği ekrana sabit (yatay kaydırma yok).
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.Spacing.l),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.Spacing.l),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Theme.Spacing.l),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Theme.Spacing.l),
        ])
    }

    private func makeChartCard() -> UIView {
        chartView.gridColor = Theme.Color.border
        chartView.upColor = Theme.Color.up
        chartView.downColor = Theme.Color.down
        chartView.crosshairColor = Theme.Color.textSecondary
        chartView.backgroundColor = Theme.Color.surface
        chartView.onSelectionChanged = { [weak self] index in self?.chartSelectionChanged(index) }
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.heightAnchor.constraint(equalToConstant: 220).isActive = true

        rangeControl.selectedSegmentTintColor = Theme.Color.accent
        rangeControl.backgroundColor = Theme.Color.surfaceElevated
        rangeControl.setTitleTextAttributes([.foregroundColor: Theme.Color.textSecondary], for: .normal)
        rangeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        rangeControl.addTarget(self, action: #selector(rangeChanged), for: .valueChanged)

        rangeChangeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [chartView, rangeControl, rangeChangeLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.m
        return card(containing: stack)
    }

    private func makeTradeButtons() -> UIView {
        configureTradeButton(buyButton, title: "Buy", color: Theme.Color.up, side: .buy)
        configureTradeButton(sellButton, title: "Sell", color: Theme.Color.down, side: .sell)
        // Pozisyon yokken Sell gizli; Buy tüm genişliği kaplar (fillEqually + gizli view).
        sellButton.isHidden = true
        let row = UIStackView(arrangedSubviews: [sellButton, buyButton])
        row.distribution = .fillEqually
        row.spacing = Theme.Spacing.m
        return row
    }

    private func makePositionCard() -> UIView {
        let title = UILabel()
        title.text = "Your position"
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.textColor = Theme.Color.textSecondary

        positionSummaryLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        positionSummaryLabel.textColor = Theme.Color.textPrimary
        positionValueLabel.font = Theme.Font.price
        positionValueLabel.textColor = Theme.Color.textPrimary
        positionValueLabel.textAlignment = .right
        positionProfitLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        positionProfitLabel.textAlignment = .right

        let left = UIStackView(arrangedSubviews: [title, positionSummaryLabel])
        left.axis = .vertical
        left.spacing = Theme.Spacing.xs
        let right = UIStackView(arrangedSubviews: [positionValueLabel, positionProfitLabel])
        right.axis = .vertical
        right.alignment = .trailing
        right.spacing = Theme.Spacing.xs
        let row = UIStackView(arrangedSubviews: [left, right])
        row.alignment = .center

        let card = card(containing: row)
        card.isHidden = true
        positionCardContainer = card
        return card
    }

    private func configureTradeButton(_ button: UIButton, title: String, color: UIColor, side: OrderSide) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.cornerStyle = .large
        configuration.buttonSize = .large
        button.configuration = configuration
        // VC sadece "al'a basıldı" der; sayfayı açmak Router'ın işi.
        button.addAction(UIAction { [weak self] _ in self?.router.routeToTradeTicket(side: side) }, for: .touchUpInside)
    }

    private func makeStatsRow() -> UIView {
        let high = statView(title: "High", valueLabel: highValueLabel)
        let low = statView(title: "Low", valueLabel: lowValueLabel)
        let row = UIStackView(arrangedSubviews: [high, low])
        row.distribution = .fillEqually
        row.spacing = Theme.Spacing.m
        return row
    }

    private func statView(title: String, valueLabel: UILabel) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = Theme.Color.textSecondary

        valueLabel.font = Theme.Font.price
        valueLabel.textColor = Theme.Color.textPrimary

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.xs
        return card(containing: stack)
    }

    /// Temanın kart görünümü: lacivert zemin, yuvarlak köşe, ince kenarlık.
    private func card(containing content: UIView) -> UIView {
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

    private func apply(_ header: StockDetail.Header) {
        if !header.name.isEmpty { nameLabel.text = header.name }
        priceLabel.text = header.price
        dayChangeLabel.text = header.dayChange
        dayChangeLabel.textColor = header.dayTrend.color
        dayChangeLabel.backgroundColor = header.dayTrend.color.withAlphaComponent(0.15)
    }

    private func chartData(_ chart: StockDetail.Chart) -> ChartData {
        ChartData(
            points: chart.points.map { ChartPoint(open: $0.open, high: $0.high, low: $0.low, close: $0.close) },
            baseline: chart.baseline
        )
    }
}

// MARK: - StockDetailDisplayLogic

extension StockDetailViewController: StockDetailDisplayLogic {

    func displayInitial(viewModel: StockDetail.Initial.ViewModel) {
        title = viewModel.title
        if let header = viewModel.header { apply(header) }
    }

    func displayMarketStatus(viewModel: StockDetail.MarketStatus.ViewModel) {
        statusBanner.show(viewModel.bannerMessage)
        buyButton.isEnabled = viewModel.isTradingEnabled
        sellButton.isEnabled = viewModel.isTradingEnabled
    }

    func displayHolding(viewModel: StockDetail.Holding.ViewModel) {
        sellButton.isHidden = !viewModel.canSell
        guard let card = viewModel.card else {
            positionCardContainer?.isHidden = true
            return
        }
        positionCardContainer?.isHidden = false
        positionSummaryLabel.text = card.summary
        positionValueLabel.text = card.value
        positionProfitLabel.text = card.profitLoss
        positionProfitLabel.textColor = card.trend.color
    }

    func displayDetail(viewModel: StockDetail.Load.ViewModel) {
        title = viewModel.title
        apply(viewModel.header)

        if rangeControl.numberOfSegments != viewModel.rangeTitles.count {
            rangeControl.removeAllSegments()
            for (index, title) in viewModel.rangeTitles.enumerated() {
                rangeControl.insertSegment(withTitle: title, at: index, animated: false)
            }
        }
        rangeControl.selectedSegmentIndex = viewModel.selectedRangeIndex

        chartView.setData(chartData(viewModel.chart), lineColor: viewModel.chart.trend.color, animated: true)
        rangeChangeLabel.text = viewModel.rangeChange
        rangeChangeLabel.textColor = viewModel.rangeTrend.color
        highValueLabel.text = viewModel.high
        lowValueLabel.text = viewModel.low
    }

    func displayQuoteUpdate(viewModel: StockDetail.Update.ViewModel) {
        if !isScrubbing { apply(viewModel.header) }
        rangeChangeLabel.text = viewModel.rangeChange
        rangeChangeLabel.textColor = viewModel.rangeTrend.color
        // Canlı güncellemede animasyon yok: sadece grafiğin ucu oynar.
        chartView.setData(chartData(viewModel.chart), lineColor: viewModel.chart.trend.color, animated: false)
    }

    func displaySelection(viewModel: StockDetail.Select.ViewModel) {
        apply(viewModel.header)
    }

    func displayLoadError(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
