import Foundation
import Testing
import Domain
@testable import StockSim

private let aksa = Instrument(symbol: Symbol("AKSA"), name: "Aksa Akrilik")
private let aksen = Instrument(symbol: Symbol("AKSEN"), name: "Aksa Enerji")

@MainActor
private final class WorkerFake: StockSearchWorking {
    var results: [String: [Instrument]] = [:]
    var fails = false
    var inWatchlist: Set<Symbol> = []
    private(set) var queries: [String] = []
    private(set) var added: [Instrument] = []

    func search(_ query: String) async throws -> [Instrument] {
        queries.append(query)
        if fails { throw URLError(.notConnectedToInternet) }
        return results[query] ?? []
    }
    func suggestions() async -> [Instrument] { [aksa] }
    func watchlistSymbols() async -> Set<Symbol> { inWatchlist }
    func add(_ instrument: Instrument) async { added.append(instrument) }
}

@MainActor
private final class PresenterSpy: StockSearchPresentationLogic {
    private(set) var responses: [StockSearch.Response] = []
    func presentSearch(response: StockSearch.Response) { responses.append(response) }
}

@MainActor
private func states(_ presenter: PresenterSpy) -> [String] {
    presenter.responses.map {
        switch $0.state {
        case .idle: "idle"
        case .loading: "loading"
        case let .results(items): "results(\(items.count))"
        case .empty: "empty"
        case .failed: "failed"
        }
    }
}

@MainActor
struct StockSearchInteractorTests {

    /// Bekleme sırasında yeni harf gelirse eski arama hiç gönderilmez (debounce).
    @Test func onlyTheLastQueryIsSent() async {
        let worker = WorkerFake()
        worker.results["aksa"] = [aksa]
        let interactor = StockSearchInteractor(
            presenter: PresenterSpy(), worker: worker,
            debounce: .milliseconds(200), sleep: { try await Task.sleep(for: $0) }
        )

        let first = Task { await interactor.search(request: .init(text: "ak")) }
        await Task.yield()
        await interactor.search(request: .init(text: "aksa"))
        await first.value

        #expect(worker.queries == ["aksa"])
    }

    @Test func searchShowsLoadingThenResults() async {
        let worker = WorkerFake()
        worker.results["aks"] = [aksa, aksen]
        let presenter = PresenterSpy()
        let interactor = StockSearchInteractor(presenter: presenter, worker: worker, sleep: { _ in })

        await interactor.search(request: .init(text: "aks"))

        #expect(states(presenter) == ["loading", "results(2)"])
    }

    @Test(arguments: [false, true])
    func emptyOrFailedSearch(fails: Bool) async {
        let worker = WorkerFake()
        worker.fails = fails
        let presenter = PresenterSpy()
        let interactor = StockSearchInteractor(presenter: presenter, worker: worker, sleep: { _ in })

        await interactor.search(request: .init(text: "zzz"))

        #expect(states(presenter).last == (fails ? "failed" : "empty"))
    }

    /// Kutu boşalınca istek atılmadan önerilere dönülür.
    @Test func clearingTheQueryShowsSuggestions() async {
        let worker = WorkerFake()
        let presenter = PresenterSpy()
        let interactor = StockSearchInteractor(presenter: presenter, worker: worker, sleep: { _ in })

        await interactor.search(request: .init(text: "   "))

        #expect(worker.queries.isEmpty)
        #expect(states(presenter) == ["idle"])
    }

    /// Eklenen hisse listeye gider ve aynı sonuçlarda "eklendi" görünür.
    @Test func addMarksTheRowAsAdded() async {
        let worker = WorkerFake()
        worker.results["aks"] = [aksa, aksen]
        let presenter = PresenterSpy()
        let interactor = StockSearchInteractor(presenter: presenter, worker: worker, sleep: { _ in })
        await interactor.search(request: .init(text: "aks"))

        await interactor.add(request: .init(instrument: aksa))

        #expect(worker.added == [aksa])
        #expect(presenter.responses.last?.watchlist == [aksa.symbol])
        #expect(states(presenter).last == "results(2)")
    }
}

@MainActor
private final class DisplaySpy: StockSearchDisplayLogic {
    private(set) var viewModels: [StockSearch.ViewModel] = []
    func displaySearch(viewModel: StockSearch.ViewModel) { viewModels.append(viewModel) }
}

@MainActor
struct StockSearchPresenterTests {

    private func present(_ state: StockSearch.Response.State, watchlist: Set<Symbol> = []) -> StockSearch.ViewModel? {
        let presenter = StockSearchPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        presenter.presentSearch(response: .init(state: state, watchlist: watchlist))
        return display.viewModels.first
    }

    @Test func resultsMarkAddedRows() throws {
        let viewModel = try #require(present(.results([aksa, aksen]), watchlist: [aksa.symbol]))
        #expect(viewModel.sectionTitle == "Results")
        #expect(viewModel.rows.map(\.isAdded) == [true, false])
    }

    @Test func emptyShowsQueryInMessage() throws {
        #expect(try #require(present(.empty(query: "zzz"))).message == "No stocks found for “zzz”.")
    }

    @Test func loadingHasNoRows() throws {
        let viewModel = try #require(present(.loading))
        #expect(viewModel.isLoading)
        #expect(viewModel.rows.isEmpty)
    }
}
