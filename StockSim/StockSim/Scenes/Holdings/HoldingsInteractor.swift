import Domain

@MainActor
protocol HoldingsBusinessLogic {
    func load() async
    /// Fiyatları ve hesabı aynı anda dinler; Task iptal edilene kadar döner.
    func startLiveUpdates() async
    func resetAccount() async
}

@MainActor
protocol HoldingsDataStore {
    /// Pozisyona dokunulunca detaya aktarılacak hisse bilgisi.
    func instrument(for symbol: Symbol) -> Instrument?
    func quote(for symbol: Symbol) -> Quote?
}

/// Portföy ekranının iş akışı. Hesaplamalar Domain'de (`Portfolio`, `Position`);
/// burası sadece hesabı ve canlı fiyatları bir araya getirip Presenter'a verir.
@MainActor
final class HoldingsInteractor: HoldingsBusinessLogic, HoldingsDataStore {

    private let presenter: HoldingsPresentationLogic
    private let worker: HoldingsWorking

    private var instruments: [Symbol: Instrument] = [:]
    private var quotes: [Symbol: Quote] = [:]
    private var portfolio: Portfolio?

    init(presenter: HoldingsPresentationLogic, worker: HoldingsWorking) {
        self.presenter = presenter
        self.worker = worker
    }

    func instrument(for symbol: Symbol) -> Instrument? { instruments[symbol] }
    func quote(for symbol: Symbol) -> Quote? { quotes[symbol] }

    func load() async {
        let list = (try? await worker.fetchInstruments()) ?? []
        instruments = Dictionary(list.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
        let loaded = (try? await worker.fetchQuotes(for: list.map(\.symbol))) ?? []
        quotes = Dictionary(loaded.map { ($0.symbol, $0) }, uniquingKeysWith: { _, latest in latest })
        portfolio = await worker.currentPortfolio()
        present()
    }

    func startLiveUpdates() async {
        async let market: Void = listenToMarket()
        async let account: Void = listenToPortfolio()
        _ = await (market, account)
    }

    func resetAccount() async {
        // Yeni hal portföy akışından gelecek; burada ayrıca göstermeye gerek yok.
        await worker.resetPortfolio()
    }

    // MARK: - Akışlar

    private func listenToMarket() async {
        for await update in await worker.liveUpdates(for: Array(instruments.keys)) {
            guard case let .quote(quote) = update else { continue }
            quotes[quote.symbol] = quote
            // Sadece elde tutulan hisselerin fiyatı ekranı etkiler.
            if portfolio?.positions[quote.symbol].map({ $0.quantity > 0 }) == true {
                present()
            }
        }
    }

    private func listenToPortfolio() async {
        for await updated in await worker.portfolioChanges() {
            portfolio = updated
            present()
        }
    }

    private func present() {
        guard let portfolio else { return }
        presenter.presentHoldings(response: Holdings.Load.Response(
            portfolio: portfolio,
            quotes: quotes,
            names: instruments.mapValues(\.name)
        ))
    }
}
