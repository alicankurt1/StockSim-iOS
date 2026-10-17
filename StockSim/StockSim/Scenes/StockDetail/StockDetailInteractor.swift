import Domain

@MainActor
protocol StockDetailBusinessLogic {
    /// Senkron: ekran ilk çizilmeden önce elde olan bilgiyi gösterir (kayma/boşluk olmasın).
    func prepare()
    func load(request: StockDetail.Load.Request) async
    /// Akış bitene ya da çağıran Task iptal edilene kadar döner.
    func startLiveUpdates(request: StockDetail.Update.Request) async
    func selectPoint(request: StockDetail.Select.Request)
}

/// Önceki ekranın Router'ı buraya yazar (DataPassing). `AnyObject`: Router referansla günceller.
@MainActor
protocol StockDetailDataStore: AnyObject {
    var instrument: Instrument? { get set }
    /// Önceki ekranın bildiği son fiyat (varsa).
    var initialQuote: Quote? { get set }
}

@MainActor
final class StockDetailInteractor: StockDetailBusinessLogic, StockDetailDataStore {

    private let presenter: StockDetailPresentationLogic
    private let worker: StockDetailWorking

    var instrument: Instrument?
    var initialQuote: Quote?

    private var range: ChartRange = .day
    private var candles: [Candle] = []
    private var lastQuote: Quote?
    private var position: Position?
    private var isHalted = false
    private var isFeedInterrupted = false

    init(presenter: StockDetailPresentationLogic, worker: StockDetailWorking) {
        self.presenter = presenter
        self.worker = worker
    }

    func prepare() {
        guard let instrument else { return }
        lastQuote = initialQuote
        presenter.presentInitial(response: StockDetail.Initial.Response(instrument: instrument, quote: initialQuote))
    }

    func load(request: StockDetail.Load.Request) async {
        guard let instrument else {
            presenter.presentLoadError()
            return
        }
        range = request.range
        do {
            async let quote = worker.fetchQuote(for: instrument.symbol)
            async let history = worker.fetchHistory(for: instrument.symbol, range: request.range)
            let (loadedQuote, loadedCandles) = try await (quote, history)

            // Beklerken kullanıcı başka bir aralığa geçtiyse bu sonuç eskidi: gösterme.
            // (await noktalarında başka işler araya girebilir — "reentrancy".)
            guard request.range == range else { return }
            guard let loadedQuote else {
                presenter.presentLoadError()
                return
            }

            candles = loadedCandles
            lastQuote = loadedQuote
            presenter.presentDetail(response: StockDetail.Load.Response(
                instrument: instrument, quote: loadedQuote, candles: loadedCandles, range: request.range
            ))
        } catch {
            guard request.range == range else { return }
            presenter.presentLoadError()
        }
    }

    /// İki akışı aynı anda dinler: piyasa (fiyat) ve portföy (pozisyon).
    /// `async let` ikisini paralel başlatır; çağıran Task iptal edilince ikisi de biter.
    func startLiveUpdates(request: StockDetail.Update.Request) async {
        async let market: Void = listenToMarket()
        async let holdings: Void = listenToPortfolio()
        _ = await (market, holdings)
    }

    private func listenToMarket() async {
        guard let instrument else { return }
        for await update in await worker.liveUpdates(for: instrument.symbol) {
            switch update {
            case let .quote(quote) where quote.symbol == instrument.symbol:
                lastQuote = quote
                updateLastCandle(with: quote)
                presenter.presentQuoteUpdate(response: StockDetail.Update.Response(quote: quote, candles: candles, range: range))
                // Fiyat değişince pozisyonun kâr/zararı da değişir.
                if position != nil { presentHolding() }
            case let .halted(symbol) where symbol == instrument.symbol:
                isHalted = true
                presentMarketStatus()
            case let .resumed(symbol) where symbol == instrument.symbol:
                isHalted = false
                presentMarketStatus()
            case .feedInterrupted:
                isFeedInterrupted = true
                presentMarketStatus()
            case .feedRestored:
                isFeedInterrupted = false
                presentMarketStatus()
            default:
                continue
            }
        }
    }

    private func listenToPortfolio() async {
        guard let instrument else { return }
        for await portfolio in await worker.portfolioChanges() {
            let current = portfolio.positions[instrument.symbol]
            position = (current?.quantity ?? 0) > 0 ? current : nil
            presentHolding()
        }
    }

    private func presentMarketStatus() {
        presenter.presentMarketStatus(response: .init(isHalted: isHalted, isFeedInterrupted: isFeedInterrupted))
    }

    private func presentHolding() {
        presenter.presentHolding(response: StockDetail.Holding.Response(position: position, quote: lastQuote))
    }

    func selectPoint(request: StockDetail.Select.Request) {
        if let index = request.index, candles.indices.contains(index), let first = candles.first {
            presenter.presentSelection(response: .point(candles[index], rangeStart: first.open, range: range))
        } else if let instrument, let lastQuote {
            presenter.presentSelection(response: .cleared(name: instrument.name, quote: lastQuote))
        }
    }

    /// Son mum "şu an"ı temsil eder: kapanışı canlı fiyat olur, en yüksek/en düşük genişler.
    private func updateLastCandle(with quote: Quote) {
        guard let last = candles.last else { return }
        candles[candles.count - 1] = Candle(
            date: last.date,
            open: last.open,
            high: max(last.high, quote.price),
            low: min(last.low, quote.price),
            close: quote.price
        )
    }
}
