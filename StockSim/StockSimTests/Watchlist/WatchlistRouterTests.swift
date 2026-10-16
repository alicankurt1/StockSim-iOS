import Testing
import UIKit
import Domain
@testable import StockSim

/// Hedef sahnenin DataStore'u yerine geçen sahte.
@MainActor
private final class DetailDataStoreSpy: StockDetailDataStore {
    var instrument: Instrument?
}

@MainActor
private struct DataStoreStub: WatchlistDataStore {
    var instruments: [Instrument]
}

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")

/// Router testi: doğru veri hedefe yazılıyor ve ekran açılıyor mu?
@MainActor
struct WatchlistRouterTests {

    private func makeRouter(instruments: [Instrument]) -> (WatchlistRouter, UINavigationController, DetailDataStoreSpy) {
        let destinationStore = DetailDataStoreSpy()
        let router = WatchlistRouter(dataStore: DataStoreStub(instruments: instruments)) {
            (UIViewController(), destinationStore)
        }
        let source = UIViewController()
        let navigationController = UINavigationController(rootViewController: source)
        router.viewController = source
        return (router, navigationController, destinationStore)
    }

    @Test func routePassesInstrumentAndPushesDetail() {
        let (router, navigationController, destinationStore) = makeRouter(instruments: [thyao])

        router.routeToStockDetail(symbol: thyao.symbol)

        #expect(destinationStore.instrument == thyao)
        #expect(navigationController.viewControllers.count == 2)
    }

    @Test func unknownSymbolDoesNothing() {
        let (router, navigationController, destinationStore) = makeRouter(instruments: [thyao])

        router.routeToStockDetail(symbol: Symbol("NOPE"))

        #expect(destinationStore.instrument == nil)
        #expect(navigationController.viewControllers.count == 1)
    }
}
