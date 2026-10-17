import UIKit
import Domain

// "What If" sekmesi: takip edilen senaryolar ve bugünkü değerleri.
// Küçük bir sahne olduğu için VIP katmanları tek dosyada; ayrımlar (protokoller) aynı.

// MARK: - Models

enum WhatIfList {

    struct Response {
        let scenarios: [WhatIfScenario]
        let prices: [Symbol: Money]
    }

    struct ViewModel: Equatable {
        let rows: [Row]
        let emptyMessage: String?
    }

    struct Row: Equatable {
        let id: UUID
        let monogram: String
        /// "THYAO"
        let title: String
        /// "₺100.000 on 12 Apr 2026"
        let subtitle: String
        let value: String
        /// Sadece yüzde ("+%20,78"); güncel değer zaten üstte.
        let returnText: String
        let trend: PriceTrend
    }
}

/// Liste ekranının Router'ı düzenlenecek senaryoyu buradan okur.
@MainActor
protocol WhatIfListDataStore {
    func scenario(for id: UUID) -> WhatIfScenario?
}

// MARK: - Worker

protocol WhatIfListWorking: Sendable {
    func scenarioChanges() async -> AsyncStream<[WhatIfScenario]>
    func quotes(for symbols: [Symbol]) async throws -> [Quote]
    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate>
    func remove(_ id: UUID) async
}

struct WhatIfListWorker: WhatIfListWorking {
    let market: any MarketDataProviding
    let store: any WhatIfStoring

    func scenarioChanges() async -> AsyncStream<[WhatIfScenario]> { await store.changes() }
    func quotes(for symbols: [Symbol]) async throws -> [Quote] { try await market.quotes(for: symbols) }
    func liveUpdates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate> { await market.updates(for: symbols) }
    func remove(_ id: UUID) async { await store.remove(id) }
}

// MARK: - Interactor

@MainActor
protocol WhatIfListBusinessLogic {
    /// Senaryoları ve fiyatları dinler; Task iptal edilene kadar döner.
    func start() async
    func remove(id: UUID) async
}

@MainActor
final class WhatIfListInteractor: WhatIfListBusinessLogic, WhatIfListDataStore {

    private let presenter: WhatIfListPresentationLogic
    private let worker: WhatIfListWorking
    private var scenarios: [WhatIfScenario] = []
    private var prices: [Symbol: Money] = [:]

    init(presenter: WhatIfListPresentationLogic, worker: WhatIfListWorking) {
        self.presenter = presenter
        self.worker = worker
    }

    func start() async {
        async let list: Void = listenToScenarios()
        async let market: Void = listenToMarket()
        _ = await (list, market)
    }

    func remove(id: UUID) async {
        await worker.remove(id)
    }

    func scenario(for id: UUID) -> WhatIfScenario? {
        scenarios.first { $0.id == id }
    }

    private var symbols: [Symbol] {
        Array(Set(scenarios.map(\.instrument.symbol))).sorted { $0.rawValue < $1.rawValue }
    }

    private func listenToScenarios() async {
        for await updated in await worker.scenarioChanges() {
            scenarios = updated
            let missing = symbols.filter { prices[$0] == nil }
            if !missing.isEmpty, let quotes = try? await worker.quotes(for: missing) {
                quotes.forEach { prices[$0.symbol] = $0.price }
            }
            present()
        }
    }

    /// Watchlist'teki desen: senaryoların hisseleri değişince akışa yeniden abone ol.
    private func listenToMarket() async {
        while !Task.isCancelled {
            let subscribed = symbols
            var changed = false
            for await update in await worker.liveUpdates(for: subscribed) {
                if symbols != subscribed {
                    changed = true
                    break
                }
                guard case let .quote(quote) = update else { continue }
                prices[quote.symbol] = quote.price
                present()
            }
            guard changed else { return }
        }
    }

    private func present() {
        presenter.presentList(response: WhatIfList.Response(scenarios: scenarios, prices: prices))
    }
}

// MARK: - Presenter

@MainActor
protocol WhatIfListPresentationLogic {
    func presentList(response: WhatIfList.Response)
}

@MainActor
final class WhatIfListPresenter: WhatIfListPresentationLogic {

    weak var viewController: WhatIfListDisplayLogic?

    func presentList(response: WhatIfList.Response) {
        let rows = response.scenarios.map { scenario in
            // Fiyat henüz yoksa alım fiyatından değerle (K/Z sıfır).
            let price = response.prices[scenario.instrument.symbol] ?? scenario.entryPrice
            let percent = scenario.returnPercent(at: price)
            return WhatIfList.Row(
                id: scenario.id,
                monogram: String(scenario.instrument.symbol.rawValue.prefix(2)),
                title: scenario.instrument.symbol.rawValue,
                // Tarih önde: satırda en çok aranan bilgi "ne zaman".
                subtitle: "\(WhatIfBuilderPresenter.dateFormatter.string(from: scenario.startDate)) · \(PriceFormatting.amount(scenario.amount))",
                value: PriceFormatting.price(scenario.value(at: price)),
                returnText: PriceFormatting.changePercent(percent),
                trend: PriceTrend(changePercent: percent)
            )
        }
        viewController?.displayList(viewModel: WhatIfList.ViewModel(
            rows: rows,
            emptyMessage: rows.isEmpty ? "What if you had bought earlier?\nTap + to try a scenario and track it." : nil
        ))
    }
}

// MARK: - Router

@MainActor
protocol WhatIfListRoutingLogic {
    func routeToBuilder()
    /// Aynı oluşturucu ekranı, düzenleme modunda.
    func routeToEdit(id: UUID)
}

typealias WhatIfBuilderFactory = @MainActor () -> (viewController: UIViewController, dataStore: WhatIfBuilderDataStore)

@MainActor
final class WhatIfListRouter: WhatIfListRoutingLogic {

    weak var viewController: UIViewController?
    let dataStore: WhatIfListDataStore
    private let makeBuilder: WhatIfBuilderFactory

    init(dataStore: WhatIfListDataStore, makeBuilder: @escaping WhatIfBuilderFactory) {
        self.dataStore = dataStore
        self.makeBuilder = makeBuilder
    }

    func routeToBuilder() {
        present(makeBuilder().viewController)
    }

    /// DataPassing: listedeki senaryo → oluşturucunun DataStore'u. Ekran o veriyle açılır.
    func routeToEdit(id: UUID) {
        guard let scenario = dataStore.scenario(for: id) else { return }
        let destination = makeBuilder()
        destination.dataStore.editing = scenario
        present(destination.viewController)
    }

    private func present(_ builder: UIViewController) {
        let navigationController = UINavigationController(rootViewController: builder)
        Theme.style(navigationController.navigationBar)
        navigationController.sheetPresentationController?.prefersGrabberVisible = true
        viewController?.present(navigationController, animated: true)
    }
}

// MARK: - View

@MainActor
protocol WhatIfListDisplayLogic: AnyObject {
    func displayList(viewModel: WhatIfList.ViewModel)
}

final class WhatIfListViewController: UIViewController {

    private let interactor: WhatIfListBusinessLogic
    private let router: WhatIfListRoutingLogic

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!
    private var rows: [UUID: WhatIfList.Row] = [:]
    private var task: Task<Void, Never>?

    init(interactor: WhatIfListBusinessLogic, router: WhatIfListRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
        title = "What If"
        navigationItem.largeTitleDisplayMode = .always
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        extendedLayoutIncludesOpaqueBars = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in
            self?.router.routeToBuilder()
        })

        var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let id = self?.dataSource.itemIdentifier(for: indexPath) else { return nil }
            let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, completion in
                Task { await self?.interactor.remove(id: id) }
                completion(true)
            }
            return UISwipeActionsConfiguration(actions: [remove])
        }
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
            section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 32, trailing: 16)
            return section
        }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Theme.Color.background
        collectionView.delegate = self
        view.addSubview(collectionView)

        let registration = UICollectionView.CellRegistration<CardRowCell, UUID> { [weak self] cell, _, id in
            guard let row = self?.rows[id] else { return }
            cell.configure(with: .init(
                badge: .text(row.monogram), badgeColor: Theme.Color.accent,
                title: row.title, subtitle: row.subtitle, value: row.value,
                detail: row.returnText, detailColor: row.trend.color
            ))
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        task = Task { [interactor] in await interactor.start() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        task?.cancel()
    }
}

extension WhatIfListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        router.routeToEdit(id: id)
    }
}

extension WhatIfListViewController: WhatIfListDisplayLogic {

    func displayList(viewModel: WhatIfList.ViewModel) {
        rows = Dictionary(uniqueKeysWithValues: viewModel.rows.map { ($0.id, $0) })
        let ids = viewModel.rows.map(\.id)

        let current = dataSource.snapshot()
        if current.itemIdentifiers == ids {
            var refreshed = current
            refreshed.reconfigureItems(ids)
            dataSource.apply(refreshed, animatingDifferences: false)
        } else {
            var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
            snapshot.appendSections([0])
            snapshot.appendItems(ids)
            dataSource.apply(snapshot, animatingDifferences: !current.itemIdentifiers.isEmpty)
        }

        if let message = viewModel.emptyMessage {
            let label = UILabel()
            label.text = message
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = Theme.Color.textSecondary
            collectionView.backgroundView = label
        } else {
            collectionView.backgroundView = nil
        }
    }
}
