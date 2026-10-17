import UIKit
import Domain

/// Presenter'ın VC'ye verebileceği hazır sonuçlar.
/// `AnyObject`: Presenter bunu `weak` tutabilsin diye (sadece class'lar weak tutulabilir).
@MainActor
protocol WatchlistDisplayLogic: AnyObject {
    func displayWatchlist(viewModel: Watchlist.Load.ViewModel)
    func displayLoadError(message: String)
    func displayQuoteUpdate(viewModel: Watchlist.Update.ViewModel)
    func displayFeedStatus(viewModel: Watchlist.FeedStatus.ViewModel)
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

        var isPlaceholder: Bool {
            if case .placeholder = self { true } else { false }
        }
    }

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, ItemID>!
    /// Kimlikten içeriğe: hücre çizilirken güncel satır buradan okunur.
    private var rows: [Symbol: Watchlist.Row] = [:]

    private let statusBanner = StatusBannerView()
    private var hasLoaded = false
    private var liveUpdatesTask: Task<Void, Never>?

    init(interactor: WatchlistBusinessLogic, router: WatchlistRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
        title = "Watchlist"
        navigationItem.largeTitleDisplayMode = .always
        // Sistem "Edit/Done" düğmesi: `setEditing` çağırır.
        navigationItem.leftBarButtonItem = editButtonItem
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        // Navigation bar opak: içerik yine de bar'ın altına uzansın. Aksi halde büyük başlık
        // küçülüp büyürken (detaya gidiş/dönüş) listenin çerçevesi değişir ve içerik kayar.
        extendedLayoutIncludesOpaqueBars = true
        setUpCollectionView()
        setUpDataSource()
        setUpReordering()
        statusBanner.install(in: view)
        let addButton = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in
            // VC arama ekranını bilmez; Router'a "ekleme istendi" der.
            self?.router.routeToSearch()
        })
        addButton.accessibilityLabel = "Add stock"
        // Assembler'ın koyduğu veri kaynağı rozeti korunur, "+" yanına eklenir.
        navigationItem.rightBarButtonItems = [addButton] + (navigationItem.rightBarButtonItems ?? [])
    }

    /// Düzenleme modu: kartların yanında sil ve sürükle düğmeleri görünür.
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = editing
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
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Theme.Color.background
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    /// Compositional layout'un "liste" bölümü: kaydırarak silme ve düzenleme modu hazır gelir.
    /// Ayırıcı çizgiler ve arka plan kapalı; görünüm kartlarda. Kartlar arası boşluk hücrenin içinde.
    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            configuration.showsSeparators = false
            configuration.backgroundColor = .clear
            configuration.trailingSwipeActionsConfigurationProvider = { indexPath in
                self?.removeAction(at: indexPath)
            }
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: Theme.Spacing.xs, leading: Theme.Spacing.l, bottom: Theme.Spacing.l * 2, trailing: Theme.Spacing.l
            )
            return section
        }
    }

    /// Kaydırınca "Remove". Skeleton satırlarında yok.
    private func removeAction(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case let .stock(symbol) = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let remove = UIContextualAction(style: .destructive, title: "Remove") { [interactor] _, _, completion in
            Task { await interactor.removeStock(request: .init(symbol: symbol)) }
            completion(true)
        }
        remove.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [remove])
    }

    /// Sürükleyerek sıralama: diffable yeni sırayı uygular, biz de Interactor'a bildiririz.
    private func setUpReordering() {
        dataSource.reorderingHandlers.canReorderItem = { id in
            if case .stock = id { true } else { false }
        }
        dataSource.reorderingHandlers.didReorder = { [interactor] transaction in
            let symbols = transaction.finalSnapshot.itemIdentifiers.compactMap { id -> Symbol? in
                if case let .stock(symbol) = id { symbol } else { nil }
            }
            Task { await interactor.reorder(request: .init(symbols: symbols)) }
        }
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
            // Sadece düzenleme modunda görünür: soldaki sil, sağdaki sürükle tutamacı.
            cell.accessories = id.isPlaceholder ? [] : [.delete(displayed: .whenEditing), .reorder(displayed: .whenEditing)]
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
    }
}

// MARK: - Seçim

extension WatchlistViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        // Skeleton kutusuna dokunulursa bir şey yapma.
        guard case let .stock(symbol) = dataSource.itemIdentifier(for: indexPath) else { return }
        // VC nereye gidileceğini bilmez; sadece Router'a "bu hisse seçildi" der.
        router.routeToStockDetail(symbol: symbol)
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
        showEmptyMessage(viewModel.emptyMessage)

        let current = dataSource.snapshot()
        if current.itemIdentifiers == ids {
            // Aynı liste, içerik değişmiş olabilir: hücreleri yerinde yenile.
            var refreshed = current
            refreshed.reconfigureItems(ids)
            dataSource.apply(refreshed, animatingDifferences: false)
            return
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(ids)
        // Skeleton → veri, ekleme/çıkarma: animasyonlu (ilk açılışta değil).
        dataSource.apply(snapshot, animatingDifferences: !current.itemIdentifiers.isEmpty)
    }

    /// Boş liste mesajı: collection view'ın arka plan view'ı olarak.
    private func showEmptyMessage(_ message: String?) {
        guard let message else {
            collectionView.backgroundView = nil
            return
        }
        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = Theme.Color.textSecondary
        collectionView.backgroundView = label
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

    func displayFeedStatus(viewModel: Watchlist.FeedStatus.ViewModel) {
        statusBanner.show(viewModel.message)
    }

    func displayLoadError(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
