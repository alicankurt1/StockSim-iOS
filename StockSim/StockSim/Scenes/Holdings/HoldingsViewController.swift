import UIKit
import Domain

@MainActor
protocol HoldingsDisplayLogic: AnyObject {
    func displayHoldings(viewModel: Holdings.Load.ViewModel)
}

/// Portföy sekmesi: hesap kartı + pozisyonlar + işlem geçmişi, tek bir collection view'da.
///
/// Üç bölüm (section) farklı düzende: compositional layout her bölüme kendi
/// `NSCollectionLayoutSection`'ını verir; pozisyonlar ve geçmişin başlığı var, kartın yok.
final class HoldingsViewController: UIViewController {

    private let interactor: HoldingsBusinessLogic
    private let router: HoldingsRoutingLogic

    private enum Section: Int, CaseIterable {
        case account, positions, activity

        var title: String? {
            switch self {
            case .account: nil
            case .positions: "Positions"
            case .activity: "Activity"
            }
        }
    }

    /// Kimlikler sabit: fiyat değişince satır silinip eklenmez, `reconfigureItems` ile yenilenir.
    private enum ItemID: Hashable {
        case account
        case position(Symbol)
        case trade(UUID)
        case empty(Section)
    }

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, ItemID>!
    /// Hücreler çizilirken güncel veriyi buradan okur.
    private var viewModel: Holdings.Load.ViewModel?

    private var hasLoaded = false
    private var liveUpdatesTask: Task<Void, Never>?

    init(interactor: HoldingsBusinessLogic, router: HoldingsRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
        title = "Portfolio"
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
        setUpCollectionView()
        setUpDataSource()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.counterclockwise"),
            primaryAction: UIAction { [weak self] _ in self?.confirmReset() }
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Reset account"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        liveUpdatesTask = Task { [weak self, interactor] in
            if self?.hasLoaded == false {
                await interactor.load()
                self?.hasLoaded = true
            }
            await interactor.startLiveUpdates()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        liveUpdatesTask?.cancel()
        liveUpdatesTask = nil
    }

    // MARK: - Kullanıcı olayları

    private func confirmReset() {
        let alert = UIAlertController(
            title: "Reset account?",
            message: "All positions and activity will be cleared and your cash returns to the starting balance.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [interactor] _ in
            Task { await interactor.resetAccount() }
        })
        present(alert, animated: true)
    }

    // MARK: - Kurulum

    private func setUpCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Theme.Color.background
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(72))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
            let section = NSCollectionLayoutSection(group: group)
            // Satır kartları aralarındaki boşluğu kendi içinde taşıyor (CardRowCell).
            section.interGroupSpacing = 0
            section.contentInsets = NSDirectionalEdgeInsets(
                top: Theme.Spacing.s, leading: Theme.Spacing.l, bottom: Theme.Spacing.l, trailing: Theme.Spacing.l
            )
            if Section(rawValue: sectionIndex)?.title != nil {
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(32)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
            }
            return section
        }
    }

    private func setUpDataSource() {
        let accountRegistration = UICollectionView.CellRegistration<AccountCardCell, ItemID> { [weak self] cell, _, _ in
            guard let card = self?.viewModel?.account else { return }
            cell.configure(with: card)
        }
        let rowRegistration = UICollectionView.CellRegistration<CardRowCell, ItemID> { [weak self] cell, _, id in
            switch id {
            case let .position(symbol):
                if let row = self?.viewModel?.positions.first(where: { $0.id == symbol }) { cell.configure(with: .init(row)) }
            case let .trade(tradeID):
                if let row = self?.viewModel?.activity.first(where: { $0.id == tradeID }) { cell.configure(with: .init(row)) }
            default:
                break
            }
        }
        let emptyRegistration = UICollectionView.CellRegistration<HoldingsEmptyCell, ItemID> { cell, _, id in
            guard case let .empty(section) = id else { return }
            cell.configure(message: section == .positions
                ? "No positions yet.\nBuy a stock from the Watchlist."
                : "Your trades will appear here.")
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<HoldingsSectionHeader>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { header, _, indexPath in
            header.label.text = Section(rawValue: indexPath.section)?.title
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            switch id {
            case .account:
                collectionView.dequeueConfiguredReusableCell(using: accountRegistration, for: indexPath, item: id)
            case .position, .trade:
                collectionView.dequeueConfiguredReusableCell(using: rowRegistration, for: indexPath, item: id)
            case .empty:
                collectionView.dequeueConfiguredReusableCell(using: emptyRegistration, for: indexPath, item: id)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }
}

// MARK: - Seçim

extension HoldingsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if case .position = dataSource.itemIdentifier(for: indexPath) { return true }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard case let .position(symbol) = dataSource.itemIdentifier(for: indexPath) else { return }
        router.routeToStockDetail(symbol: symbol)
    }
}

// MARK: - HoldingsDisplayLogic

extension HoldingsViewController: HoldingsDisplayLogic {

    func displayHoldings(viewModel: Holdings.Load.ViewModel) {
        self.viewModel = viewModel

        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemID>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems([.account], toSection: .account)
        snapshot.appendItems(
            viewModel.positions.isEmpty ? [.empty(.positions)] : viewModel.positions.map { .position($0.id) },
            toSection: .positions
        )
        snapshot.appendItems(
            viewModel.activity.isEmpty ? [.empty(.activity)] : viewModel.activity.map { .trade($0.id) },
            toSection: .activity
        )

        let current = dataSource.snapshot()
        if current.itemIdentifiers == snapshot.itemIdentifiers {
            // Aynı satırlar, değişen sadece içerik (fiyat): hücreleri yerinde yenile.
            var refreshed = current
            refreshed.reconfigureItems(current.itemIdentifiers)
            dataSource.apply(refreshed, animatingDifferences: false)
        } else {
            // Yeni işlem / kapanan pozisyon: satırlar eklenip çıkarken animasyon.
            dataSource.apply(snapshot, animatingDifferences: !current.itemIdentifiers.isEmpty)
        }
    }
}

// MARK: - Satır içeriği (ViewModel → kart satırı)

private extension CardRowCell.Content {

    init(_ row: Holdings.PositionRow) {
        self.init(
            badge: .text(row.monogram), badgeColor: Theme.Color.accent,
            title: row.symbol, subtitle: row.summary, value: row.value,
            detail: row.profitLoss, detailColor: row.trend.color
        )
    }

    init(_ row: Holdings.ActivityRow) {
        let isBuy = row.side == .buy
        self.init(
            badge: .symbol(isBuy ? "arrow.down.left" : "arrow.up.right"),
            badgeColor: isBuy ? Theme.Color.up : Theme.Color.down,
            title: row.title, subtitle: row.subtitle, value: row.amount, detail: nil
        )
    }
}
