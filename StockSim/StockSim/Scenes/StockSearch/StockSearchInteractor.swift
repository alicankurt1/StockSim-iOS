import Foundation
import Domain

@MainActor
protocol StockSearchBusinessLogic {
    func load() async
    /// Yazdıkça çağrılır; kendi içinde bekletir (debounce) ve eski aramaları iptal eder.
    func search(request: StockSearch.Query.Request) async
    func add(request: StockSearch.Add.Request) async
}

/// Arama iş akışı.
///
/// Debounce: kullanıcı "aksa" yazarken a, ak, aks, aksa için 4 istek atmak yerine,
/// yazma durduktan kısa süre sonra sadece son metin için 1 istek atılır.
/// Yöntem: her harfte önceki bekleyen aramayı iptal et, yenisini kısa bir beklemeyle başlat.
@MainActor
final class StockSearchInteractor: StockSearchBusinessLogic {

    private let presenter: StockSearchPresentationLogic
    private let worker: StockSearchWorking
    private let debounce: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    private var searchTask: Task<Void, Never>?
    private var lastState: StockSearch.Response.State = .idle(suggestions: [])
    private var watchlist: Set<Symbol> = []

    init(
        presenter: StockSearchPresentationLogic,
        worker: StockSearchWorking,
        debounce: Duration = .milliseconds(300),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.presenter = presenter
        self.worker = worker
        self.debounce = debounce
        self.sleep = sleep
    }

    func load() async {
        watchlist = await worker.watchlistSymbols()
        present(.idle(suggestions: await worker.suggestions()))
    }

    func search(request: StockSearch.Query.Request) async {
        // Yeni harf geldi: bekleyen eski aramayı iptal et.
        searchTask?.cancel()
        let query = request.text.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            present(.idle(suggestions: await worker.suggestions()))
            return
        }

        let task = Task { [weak self, worker, debounce, sleep] in
            // 1. Bekle: bu sürede yeni harf gelirse iptal edilir, istek hiç atılmaz.
            do { try await sleep(debounce) } catch { return }
            guard !Task.isCancelled else { return }
            self?.present(.loading)

            // 2. Ara.
            let state: StockSearch.Response.State
            do {
                let results = try await worker.search(query)
                state = results.isEmpty ? .empty(query: query) : .results(results)
            } catch {
                state = .failed
            }
            // 3. Bu arada daha yeni bir arama başladıysa eski sonucu gösterme.
            guard !Task.isCancelled else { return }
            self?.present(state)
        }
        searchTask = task
        await task.value
    }

    func add(request: StockSearch.Add.Request) async {
        await worker.add(request.instrument)
        watchlist.insert(request.instrument.symbol)
        // Aynı liste, eklenen satır artık "eklendi" görünür.
        present(lastState)
    }

    private func present(_ state: StockSearch.Response.State) {
        lastState = state
        presenter.presentSearch(response: StockSearch.Response(state: state, watchlist: watchlist))
    }
}
