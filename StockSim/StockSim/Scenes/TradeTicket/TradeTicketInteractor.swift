import Domain

@MainActor
protocol TradeTicketBusinessLogic {
    func load(request: TradeTicket.Load.Request) async
    func startLiveUpdates() async
    func edit(request: TradeTicket.Edit.Request)
    func submit(request: TradeTicket.Submit.Request) async
}

@MainActor
protocol TradeTicketDataStore: AnyObject {
    var instrument: Instrument? { get set }
    var side: OrderSide { get set }
}

/// Al/sat iş kuralları.
///
/// Kuralları yeniden yazmıyor: formu doğrulamak için portföyün bir KOPYASINDA emri
/// "deneme olarak" çalıştırıyor. Domain'deki `Portfolio.execute` ne derse o (tek doğruluk kaynağı).
@MainActor
final class TradeTicketInteractor: TradeTicketBusinessLogic, TradeTicketDataStore {

    private let presenter: TradeTicketPresentationLogic
    private let worker: TradeTicketWorking

    var instrument: Instrument?
    var side: OrderSide = .buy

    private var quantity = 1
    private var quote: Quote?
    private var portfolio: Portfolio?
    private var isHalted = false
    private var isSubmitting = false

    init(presenter: TradeTicketPresentationLogic, worker: TradeTicketWorking) {
        self.presenter = presenter
        self.worker = worker
    }

    func load(request: TradeTicket.Load.Request) async {
        guard let instrument else { return }
        portfolio = await worker.currentPortfolio()
        quote = try? await worker.fetchQuote(for: instrument.symbol)
        presentForm()
    }

    func startLiveUpdates() async {
        guard let instrument else { return }
        for await update in await worker.liveUpdates(for: instrument.symbol) {
            switch update {
            case let .quote(newQuote) where newQuote.symbol == instrument.symbol:
                quote = newQuote
            case let .halted(symbol) where symbol == instrument.symbol:
                isHalted = true
            case let .resumed(symbol) where symbol == instrument.symbol:
                isHalted = false
            default:
                continue
            }
            presentForm()
        }
    }

    func edit(request: TradeTicket.Edit.Request) {
        if let side = request.side { self.side = side }
        if let quantity = request.quantity { self.quantity = quantity }
        presentForm()
    }

    func submit(request: TradeTicket.Submit.Request) async {
        // Çift dokunuşta iki emir gitmesin.
        guard !isSubmitting, let instrument, let quote else { return }
        guard validationError() == nil else {
            presentForm()
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let trade = try await worker.execute(order(for: instrument), at: quote)
            portfolio = await worker.currentPortfolio()
            presenter.presentTradeCompleted(response: TradeTicket.Submit.Response(trade: trade))
        } catch {
            // Doğrulamadan sonra durum değişmiş olabilir (ör. başka ekranda alım yapıldı).
            portfolio = await worker.currentPortfolio()
            presentForm()
        }
    }

    // MARK: - Form

    private func order(for instrument: Instrument) -> Order {
        Order(symbol: instrument.symbol, side: side, quantity: quantity)
    }

    /// Emir şu an gönderilse hangi kurala takılırdı?
    private func validationError() -> TradingError? {
        guard let instrument, let quote, var draft = portfolio else { return nil }
        if isHalted { return .marketHalted(instrument.symbol) }
        do {
            // Kopya üzerinde dene: gerçek portföy değişmez (struct = değer tipi).
            try draft.execute(order(for: instrument), at: quote)
            return nil
        } catch let error as TradingError {
            return error
        } catch {
            return nil
        }
    }

    private func presentForm() {
        guard let instrument else { return }
        presenter.presentForm(response: TradeTicket.FormResponse(
            instrument: instrument,
            side: side,
            quantity: quantity,
            quote: quote,
            cash: portfolio?.cash ?? .zero,
            ownedQuantity: portfolio?.positions[instrument.symbol]?.quantity ?? 0,
            error: validationError()
        ))
    }
}
