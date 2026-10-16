import Testing
import UIKit
import Domain
@testable import StockSim

@MainActor
private final class DetailStoreStub: StockDetailDataStore {
    var instrument: Instrument?
    var initialQuote: Quote?
}

@MainActor
private final class TicketStoreSpy: TradeTicketDataStore {
    var instrument: Instrument?
    var side: OrderSide = .buy
}

@MainActor
struct StockDetailRouterTests {

    /// Al/sat sayfasına hisse ve seçilen taraf (al/sat) aktarılır.
    @Test(arguments: [OrderSide.buy, .sell])
    func routeToTradeTicketPassesInstrumentAndSide(side: OrderSide) {
        let instrument = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
        let source = DetailStoreStub()
        source.instrument = instrument
        let destination = TicketStoreSpy()
        let router = StockDetailRouter(dataStore: source) { (UIViewController(), destination) }

        router.routeToTradeTicket(side: side)

        #expect(destination.instrument == instrument)
        #expect(destination.side == side)
    }
}
