import Foundation
import Testing
import Domain
@testable import StockSim

@MainActor
private final class DisplaySpy: TradeTicketDisplayLogic {
    private(set) var forms: [TradeTicket.FormViewModel] = []
    private(set) var completions: [TradeTicket.Submit.ViewModel] = []

    func displayForm(viewModel: TradeTicket.FormViewModel) { forms.append(viewModel) }
    func displayTradeCompleted(viewModel: TradeTicket.Submit.ViewModel) { completions.append(viewModel) }
}

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let quote = Quote(symbol: thyao.symbol, price: Money(Decimal(string: "287.5")!), previousClose: Money(280), timestamp: Date(timeIntervalSince1970: 0))

@MainActor
struct TradeTicketPresenterTests {

    private func present(side: OrderSide = .buy, quantity: Int = 10, quote: Quote? = quote, owned: Int = 0, error: TradingError? = nil) -> TradeTicket.FormViewModel? {
        let presenter = TradeTicketPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        presenter.presentForm(response: .init(
            instrument: thyao, side: side, quantity: quantity, quote: quote,
            cash: Money(100_000), ownedQuantity: owned, error: error
        ))
        return display.forms.first
    }

    @Test func buyFormShowsTotalAndCash() throws {
        let form = try #require(present())

        #expect(form.title == "Buy THYAO")
        #expect(form.price == "₺287,50")
        #expect(form.estimatedTotal == "₺2.875,00")
        #expect(form.availability == "Cash available ₺100.000,00")
        #expect(form.submitTitle == "Buy 10 shares")
        #expect(form.isSubmitEnabled)
        #expect(form.errorMessage == nil)
        #expect(!form.isSellEnabled)   // hisse yok → Sell seçilemez
    }

    @Test func sellFormShowsOwnedShares() throws {
        let form = try #require(present(side: .sell, quantity: 1, owned: 4))

        #expect(form.title == "Sell THYAO")
        #expect(form.selectedSideIndex == 1)
        #expect(form.availability == "You own 4 shares")
        #expect(form.submitTitle == "Sell 1 share")
        #expect(form.isSellEnabled)
    }

    @Test func errorDisablesSubmit() throws {
        let form = try #require(present(error: .invalidQuantity))
        #expect(!form.isSubmitEnabled)
        #expect(form.errorMessage != nil)
    }

    @Test func missingQuoteDisablesSubmit() throws {
        let form = try #require(present(quote: nil))
        #expect(!form.isSubmitEnabled)
        #expect(form.price == "—")
    }

    /// İş kuralı hatası → kullanıcı cümlesi.
    @Test(arguments: [
        (TradingError.invalidQuantity, "Enter a quantity greater than zero."),
        (.insufficientCash(available: Money(50), required: Money(100)), "Not enough cash. Available: ₺50,00."),
        (.insufficientQuantity(available: 0, requested: 1), "You don't own any THYAO shares."),
        (.insufficientQuantity(available: 3, requested: 5), "You only own 3 shares."),
        (.orderNotFillable, "This order can't be filled right now."),
        (.marketHalted(Symbol("THYAO")), "Trading is halted for THYAO."),
    ])
    func errorMessages(error: TradingError, expected: String) {
        #expect(TradeTicketPresenter.message(for: error, symbol: "THYAO") == expected)
    }

    @Test func completedTradeMessage() {
        let presenter = TradeTicketPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        let trade = Trade(symbol: thyao.symbol, side: .buy, quantity: 2, price: Money(100), date: .now)

        presenter.presentTradeCompleted(response: .init(trade: trade))

        #expect(display.completions.first?.message == "Bought 2 shares of THYAO at ₺100,00")
    }
}
