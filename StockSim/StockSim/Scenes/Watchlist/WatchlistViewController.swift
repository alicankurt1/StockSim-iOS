import UIKit

/// Presenter'ın VC'ye verebileceği hazır sonuçlar.
/// `AnyObject`: Presenter bunu `weak` tutabilsin diye (sadece class'lar weak tutulabilir).
@MainActor
protocol WatchlistDisplayLogic: AnyObject {
    func displayWatchlist(viewModel: Watchlist.Load.ViewModel)
    func displayLoadError(message: String)
}

/// View: sadece gösterir ve kullanıcı olaylarını Interactor'a iletir. Hesap yapmaz.
final class WatchlistViewController: UIViewController {

    private let interactor: WatchlistBusinessLogic
    private let router: WatchlistRoutingLogic

    private enum Section { case main }
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Watchlist.Item>!

    init(interactor: WatchlistBusinessLogic, router: WatchlistRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
        title = "Watchlist"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        setUpCollectionView()
        setUpDataSource()

        // VIP döngüsünün başı: VC → Interactor
        Task { await interactor.loadWatchlist(request: .init()) }
    }

    // MARK: - Kurulum

    private func setUpCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: Self.makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Theme.Color.background
        view.addSubview(collectionView)
    }

    /// Compositional layout: tek sütun kart listesi.
    ///
    /// Item (kart) → Group (bir satır) → Section (liste). Yükseklik `estimated`:
    /// kart, içeriğine göre (Auto Layout) kendi yüksekliğini belirler.
    private static func makeLayout() -> UICollectionViewLayout {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(68))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Theme.Spacing.s + 2
        section.contentInsets = NSDirectionalEdgeInsets(
            top: Theme.Spacing.s, leading: Theme.Spacing.l, bottom: Theme.Spacing.l * 2, trailing: Theme.Spacing.l
        )
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func setUpDataSource() {
        let registration = UICollectionView.CellRegistration<WatchlistCell, Watchlist.Item> { cell, _, item in
            switch item {
            case .placeholder:
                cell.showPlaceholder()
            case let .stock(row):
                cell.configure(with: row)
            }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }
}

// MARK: - WatchlistDisplayLogic

extension WatchlistViewController: WatchlistDisplayLogic {

    func displayWatchlist(viewModel: Watchlist.Load.ViewModel) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Watchlist.Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items)
        // Skeleton → veri geçişi yumuşak olsun (ilk açılışta animasyonsuz).
        let hadItems = !dataSource.snapshot().itemIdentifiers.isEmpty
        dataSource.apply(snapshot, animatingDifferences: hadItems)
    }

    func displayLoadError(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
