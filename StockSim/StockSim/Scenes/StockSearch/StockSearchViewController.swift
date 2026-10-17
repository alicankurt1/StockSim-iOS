import UIKit
import Domain

@MainActor
protocol StockSearchDisplayLogic: AnyObject {
    func displaySearch(viewModel: StockSearch.ViewModel)
}

/// Arama ekranı: üstte arama çubuğu, altta sonuçlar. Satıra dokununca izleme listesine eklenir.
final class StockSearchViewController: UIViewController {

    private let interactor: StockSearchBusinessLogic
    private let router: StockSearchRoutingLogic

    private let searchController = UISearchController(searchResultsController: nil)
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, StockSearch.Row>!
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var sectionTitle: String?

    init(interactor: StockSearchBusinessLogic, router: StockSearchRoutingLogic) {
        self.interactor = interactor
        self.router = router
        super.init(nibName: nil, bundle: nil)
        title = "Add Stocks"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.router.dismiss()
        })
        setUpSearch()
        setUpCollectionView()
        Task { await interactor.load() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Sayfa açılınca klavye hemen gelsin.
        searchController.searchBar.becomeFirstResponder()
    }

    // MARK: - Kurulum

    private func setUpSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "Code or company, e.g. AKSA"
        searchController.searchBar.autocapitalizationType = .allCharacters
        searchController.searchBar.autocorrectionType = .no
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func setUpCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.backgroundColor = Theme.Color.background
        configuration.headerMode = .supplementary
        collectionView = UICollectionView(
            frame: view.bounds, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration)
        )
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Theme.Color.background
        collectionView.keyboardDismissMode = .onDrag
        collectionView.delegate = self
        view.addSubview(collectionView)

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, StockSearch.Row> { cell, _, row in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = row.symbol
            content.textProperties.font = Theme.Font.symbol
            content.textProperties.color = Theme.Color.textPrimary
            content.secondaryText = row.name
            content.secondaryTextProperties.color = Theme.Color.textSecondary
            cell.contentConfiguration = content

            var background = UIBackgroundConfiguration.listGroupedCell()
            background.backgroundColor = Theme.Color.surface
            cell.backgroundConfiguration = background

            // Eklendiyse yeşil onay, değilse mavi "+".
            let symbolName = row.isAdded ? "checkmark.circle.fill" : "plus.circle.fill"
            let image = UIImageView(image: UIImage(systemName: symbolName))
            image.tintColor = row.isAdded ? Theme.Color.up : Theme.Color.accent
            cell.accessories = [.customView(configuration: .init(customView: image, placement: .trailing()))]
            cell.accessibilityLabel = "\(row.symbol), \(row.name)"
            cell.accessibilityValue = row.isAdded ? "In watchlist" : "Not in watchlist"
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, _ in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = self?.sectionTitle
            header.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, row in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: row)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }

        spinner.color = Theme.Color.textSecondary
        spinner.hidesWhenStopped = true
    }
}

// MARK: - Arama metni

extension StockSearchViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text ?? ""
        // Her harfte çağrılır; bekletme (debounce) Interactor'da.
        Task { await interactor.search(request: .init(text: text)) }
    }
}

// MARK: - Seçim

extension StockSearchViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let row = dataSource.itemIdentifier(for: indexPath), !row.isAdded else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await interactor.add(request: .init(instrument: row.instrument)) }
    }
}

// MARK: - StockSearchDisplayLogic

extension StockSearchViewController: StockSearchDisplayLogic {

    func displaySearch(viewModel: StockSearch.ViewModel) {
        sectionTitle = viewModel.sectionTitle

        var snapshot = NSDiffableDataSourceSnapshot<Int, StockSearch.Row>()
        if !viewModel.rows.isEmpty {
            snapshot.appendSections([0])
            snapshot.appendItems(viewModel.rows)
            // Başlık metni değişmiş olabilir.
            snapshot.reloadSections([0])
        }
        dataSource.apply(snapshot, animatingDifferences: false)

        if viewModel.isLoading {
            collectionView.backgroundView = spinner
            spinner.startAnimating()
        } else if let message = viewModel.message {
            spinner.stopAnimating()
            let label = UILabel()
            label.text = message
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = Theme.Color.textSecondary
            collectionView.backgroundView = label
        } else {
            spinner.stopAnimating()
            collectionView.backgroundView = nil
        }
    }
}
