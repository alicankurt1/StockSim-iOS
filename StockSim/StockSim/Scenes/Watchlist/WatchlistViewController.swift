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
    private var dataSource: UICollectionViewDiffableDataSource<Section, Watchlist.Row>!

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
        setUpCollectionView()
        setUpDataSource()

        // VIP döngüsünün başı: VC → Interactor
        Task { await interactor.loadWatchlist(request: .init()) }
    }

    // MARK: - Kurulum

    private func setUpCollectionView() {
        // Adım 3'te kendi compositional layout'umuzu yazacağız; şimdilik hazır liste düzeni.
        let layout = UICollectionViewCompositionalLayout.list(using: .init(appearance: .plain))
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }

    private func setUpDataSource() {
        // Adım 3'te özel hücreye geçeceğiz; şimdilik sistemin liste hücresi.
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Watchlist.Row> { cell, _, row in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = row.symbol
            content.secondaryText = row.name
            cell.contentConfiguration = content
            cell.accessories = [.label(text: row.price)]
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, row in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: row)
        }
    }
}

// MARK: - WatchlistDisplayLogic

extension WatchlistViewController: WatchlistDisplayLogic {

    func displayWatchlist(viewModel: Watchlist.Load.ViewModel) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Watchlist.Row>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.rows)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func displayLoadError(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
