import Testing
import UIKit
import Domain
@testable import StockSim

// Duman testleri: composition root ekranı doğru kuruyor mu, paket modülleri uygulamaya bağlı mı?
@MainActor
struct AppAssemblerTests {

    @Test func rootIsNavigationControllerWithWatchlist() throws {
        let root = AppAssembler().makeRootViewController()

        let navigationController = try #require(root as? UINavigationController)
        #expect(navigationController.topViewController?.title == "Watchlist")
    }

    @Test func marketKitIsLinked() {
        #expect(DomainModule.name == "Domain")
    }
}
