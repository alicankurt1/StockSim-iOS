import Domain

@MainActor
protocol StockDetailBusinessLogic {
    func load(request: StockDetail.Load.Request) async
    /// Akış bitene ya da çağıran Task iptal edilene kadar döner.
    func startLiveUpdates(request: StockDetail.Update.Request) async
    func selectPoint(request: StockDetail.Select.Request)
}

/// Önceki ekranın Router'ı buraya yazar (DataPassing). `AnyObject`: Router referansla günceller.
@MainActor
protocol StockDetailDataStore: AnyObject {
    var instrument: Instrument? { get set }
}

@MainActor
final class StockDetailInteractor: StockDetailBusinessLogic, StockDetailDataStore {

    private let presenter: StockDetailPresentationLogic
    private let worker: StockDetailWorking

    var instrument: Instrument?

    private var range: ChartRange = .day
    private var candles: [Candle] = []
    private var lastQuote: Quote?

    init(presenter: StockDetailPresentationLogic, worker: StockDetailWorking) {
        self.presenter = presenter
        self.worker = worker
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

    func startLiveUpdates(request: StockDetail.Update.Request) async {
        guard let instrument else { return }
        let updates = await worker.liveUpdates(for: instrument.symbol)

        for await update in updates {
            guard case let .quote(quote) = update, quote.symbol == instrument.symbol else { continue }
            lastQuote = quote
            updateLastCandle(with: quote)
            presenter.presentQuoteUpdate(response: StockDetail.Update.Response(quote: quote, candles: candles, range: range))
        }
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
