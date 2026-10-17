import XCTest

// UI duman testi: uygulama açılıyor ve ilk ekran görünüyor mu?
// (UI testleri hâlâ XCTest ile yazılıyor; Swift Testing UI testlerini desteklemiyor.)
final class StockSimUITests: XCTestCase {

    @MainActor
    func testLaunchShowsWatchlist() {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryPortfolio"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Watchlist"].waitForExistence(timeout: 5))
    }
}
