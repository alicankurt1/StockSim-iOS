import UIKit
import Domain

/// Presenter'ın VC'ye verebileceği hazır sonuçlar.
/// `AnyObject`: Presenter bunu `weak` tutabilsin diye (sadece class'lar weak tutulabilir).
@MainActor
protocol WatchlistDisplayLogic: AnyObject {
    func displayWatchlist(viewModel: Watchlist.Load.ViewModel)
    func displayLoadError(message: String)
    func displayQuoteUpdate(viewModel: Watchlist.Update.ViewModel)
}

/// View: sadece gösterir ve kullanıcı olaylarını Interactor'a iletir. Hesap yapmaz.
final class WatchlistViewController: UIViewController {

    private let interactor: WatchlistBusinessLogic
    private let router: WatchlistRoutingLogic

    private enum Section { case main }

    /// Diffable'ın KİMLİK tipi: satırın tamamı değil, sadece "hangi hisse".
    ///
    /// Kimlik satırın tamamı olsaydı, fiyat değişince diffable bunu "eski satır silindi,
    /// yeni satır eklendi" sanardı (titreme, kaydırma kayması). Kimlik sabit kalınca
    /// fiyat değişimi "aynı öğenin içeriği değişti" olur: `reconfigureItems`.
    private enum ItemID: Hashable {
        case placeholder(Int)
        case stock(Symbol)
    }

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, ItemID>!
    /// Kimlikten içeriğe: hücre çizilirken güncel satır buradan okunur.
    private var rows: [Symbol: Watchlist.Row] = [:]

    private var hasLoaded = false
    private var liveUpdatesTask: Task<Void, Never>?

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ekran görünürken canlı fiyat dinle; ilk seferde önce listeyi yükle.
        liveUpdatesTask = Task { [weak self, interactor] in
            if self?.hasLoaded == false {
                await interactor.loadWatchlist(request: .init())
                self?.hasLoaded = true
            }
            await interactor.startLiveUpdates(request: .init())
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Ekran görünmüyorsa akışı kapat: pil ve CPU boşa harcanmasın.
        liveUpdatesTask?.cancel()
        liveUpdatesTask = nil
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
        let registration = UICollectionView.CellRegistration<WatchlistCell, ItemID> { [weak self] cell, _, id in
            switch id {
            case .placeholder:
                cell.showPlaceholder()
            case let .stock(symbol):
                guard let row = self?.rows[symbol] else { return }
                cell.configure(with: row)
            }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
    }
}

// MARK: - WatchlistDisplayLogic

extension WatchlistViewController: WatchlistDisplayLogic {

    func displayWatchlist(viewModel: Watchlist.Load.ViewModel) {
        rows = Dictionary(viewModel.rows.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })

        let ids: [ItemID] = viewModel.items.map { item in
            switch item {
            case let .placeholder(index): .placeholder(index)
            case let .stock(row): .stock(row.id)
            }
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(ids)
        // Skeleton → veri geçişi yumuşak olsun (ilk açılışta animasyonsuz).
        let hadItems = !dataSource.snapshot().itemIdentifiers.isEmpty
        dataSource.apply(snapshot, animatingDifferences: hadItems)
    }

    func displayQuoteUpdate(viewModel: Watchlist.Update.ViewModel) {
        let row = viewModel.row
        rows[row.id] = row

        var snapshot = dataSource.snapshot()
        guard snapshot.indexOfItem(.stock(row.id)) != nil else { return }
        // Hücreyi yeniden yaratmadan aynı hücrenin içeriğini günceller (iOS 15+).
        // `reloadItems`'tan ucuzdur: dequeue yok, sadece registration handler tekrar çalışır.
        snapshot.reconfigureItems([.stock(row.id)])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func displayLoadError(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
