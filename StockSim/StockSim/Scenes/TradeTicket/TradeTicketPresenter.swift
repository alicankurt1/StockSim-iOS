import Foundation
import Domain

@MainActor
protocol TradeTicketPresentationLogic {
    func presentForm(response: TradeTicket.FormResponse)
    func presentTradeCompleted(response: TradeTicket.Submit.Response)
}

/// Formu ekrana hazırlar ve iş kuralı hatalarını kullanıcı diline çevirir.
@MainActor
final class TradeTicketPresenter: TradeTicketPresentationLogic {

    weak var viewController: TradeTicketDisplayLogic?

    func presentForm(response: TradeTicket.FormResponse) {
        let symbol = response.instrument.symbol.rawValue
        let verb = response.side == .buy ? "Buy" : "Sell"
        let total = response.quote.map { PriceFormatting.price($0.price * max(response.quantity, 0)) } ?? "—"
        let availability = response.side == .buy
            ? "Cash available \(PriceFormatting.price(response.cash))"
            : "You own \(PriceFormatting.shares(response.ownedQuantity))"

        viewController?.displayForm(viewModel: TradeTicket.FormViewModel(
            title: "\(verb) \(symbol)",
            selectedSideIndex: response.side == .buy ? 0 : 1,
            isSellEnabled: response.ownedQuantity > 0,
            price: response.quote.map { PriceFormatting.price($0.price) } ?? "—",
            quantityText: response.quantity > 0 ? "\(response.quantity)" : "",
            estimatedTotal: total,
            availability: availability,
            errorMessage: response.error.map { Self.message(for: $0, symbol: symbol) },
            submitTitle: "\(verb) \(PriceFormatting.shares(max(response.quantity, 0)))",
            isSubmitEnabled: response.error == nil && response.quote != nil
        ))
    }

    func presentTradeCompleted(response: TradeTicket.Submit.Response) {
        let trade = response.trade
        let verb = trade.side == .buy ? "Bought" : "Sold"
        viewController?.displayTradeCompleted(viewModel: TradeTicket.Submit.ViewModel(
            message: "\(verb) \(PriceFormatting.shares(trade.quantity)) of \(trade.symbol.rawValue) at \(PriceFormatting.price(trade.price))"
        ))
    }

    // MARK: - Hata → mesaj

    /// İş kuralı hatası (Domain) → kullanıcının anlayacağı cümle (ekran).
    /// Interactor "ne oldu"yu bilir; "nasıl söylenir" Presenter'ın işi.
    static func message(for error: TradingError, symbol: String) -> String {
        switch error {
        case .invalidQuantity:
            "Enter a quantity greater than zero."
        case let .insufficientCash(available, _):
            "Not enough cash. Available: \(PriceFormatting.price(available))."
        case let .insufficientQuantity(available, _):
            available == 0 ? "You don't own any \(symbol) shares." : "You only own \(PriceFormatting.shares(available))."
        case .orderNotFillable:
            "This order can't be filled right now."
        case .marketHalted:
            "Trading is halted for \(symbol)."
        }
    }
}
