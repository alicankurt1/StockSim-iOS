import Testing
import UIKit
import Domain
@testable import StockSim

// Duman testleri: composition root ekranı doğru kuruyor mu, paket modülleri uygulamaya bağlı mı?
@MainActor
struct AppAssemblerTests {

    /// Kaynak ne olursa olsun aynı ekranlar kurulur (LSP): simülatör ya da gerçek veri.
    @Test(arguments: [MarketDataSource.simulated, .delayed])
    func rootHasWatchlistAndPortfolioTabs(source: MarketDataSource) throws {
        let assembler = AppAssembler(
            dataSource: source, portfolioStore: PortfolioStore(), watchlistStore: WatchlistStore(), whatIfStore: WhatIfStore()
        )
        let root = try #require(assembler.makeRootViewController() as? UITabBarController)

        let titles = root.viewControllers?.compactMap { ($0 as? UINavigationController)?.topViewController?.title }
        #expect(titles == ["Watchlist", "Portfolio", "What If"])
    }

    @Test func marketKitIsLinked() {
        #expect(Money.zero.amount == 0)
    }
}
