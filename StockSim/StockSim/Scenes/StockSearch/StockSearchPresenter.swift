import Domain

@MainActor
protocol StockSearchPresentationLogic {
    func presentSearch(response: StockSearch.Response)
}

/// Arama durumlarını ekrana çevirir. UIKit bilmez.
@MainActor
final class StockSearchPresenter: StockSearchPresentationLogic {

    weak var viewController: StockSearchDisplayLogic?

    func presentSearch(response: StockSearch.Response) {
        let viewModel: StockSearch.ViewModel
        switch response.state {
        case let .idle(suggestions):
            viewModel = .init(
                sectionTitle: suggestions.isEmpty ? nil : "Popular",
                rows: rows(suggestions, watchlist: response.watchlist),
                message: suggestions.isEmpty ? "Search stocks by code or name." : nil,
                isLoading: false
            )
        case .loading:
            viewModel = .init(sectionTitle: nil, rows: [], message: nil, isLoading: true)
        case let .results(instruments):
            viewModel = .init(sectionTitle: "Results", rows: rows(instruments, watchlist: response.watchlist), message: nil, isLoading: false)
        case let .empty(query):
            viewModel = .init(sectionTitle: nil, rows: [], message: "No stocks found for “\(query)”.", isLoading: false)
        case .failed:
            viewModel = .init(sectionTitle: nil, rows: [], message: "Couldn't search right now.\nCheck your connection and try again.", isLoading: false)
        }
        viewController?.displaySearch(viewModel: viewModel)
    }

    private func rows(_ instruments: [Instrument], watchlist: Set<Symbol>) -> [StockSearch.Row] {
        instruments.map {
            StockSearch.Row(
                id: $0.symbol,
                symbol: $0.symbol.rawValue,
                name: $0.name,
                isAdded: watchlist.contains($0.symbol),
                instrument: $0
            )
        }
    }
}
