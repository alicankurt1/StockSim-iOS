import Foundation
import Testing
import Domain
@testable import Persistence

/// Her test kendi geçici klasöründe çalışır; testler birbirinin dosyasını görmez.
private func temporaryFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("StockSimTests-\(UUID().uuidString)")
        .appendingPathComponent("portfolio.json")
}

private let thyao = Symbol("THYAO")
private let date = Date(timeIntervalSince1970: 1_800_000_000)

private func quote(_ price: String) -> Quote {
    Quote(symbol: thyao, price: Money(Decimal(string: price)!), previousClose: Money(100), timestamp: date)
}

/// Kuruşlu, bölmeli ortalama maliyetli gerçekçi bir hesap.
private func samplePortfolio() throws -> Portfolio {
    var portfolio = Portfolio(cash: Money(100_000))
    try portfolio.execute(Order(symbol: thyao, side: .buy, quantity: 3), at: quote("287.55"))
    try portfolio.execute(Order(symbol: thyao, side: .buy, quantity: 4), at: quote("290.10"))
    try portfolio.execute(Order(symbol: thyao, side: .sell, quantity: 2), at: quote("301.35"))
    return portfolio
}

struct FilePortfolioRepositoryTests {

    @Test func missingFileLoadsNil() throws {
        #expect(try FilePortfolioRepository(fileURL: temporaryFile()).load() == nil)
    }

    /// Kaydet → oku: her şey birebir aynı (ortalama maliyetin uzun ondalıkları dahil).
    @Test func roundTripPreservesEverything() throws {
        let repository = FilePortfolioRepository(fileURL: temporaryFile())
        let portfolio = try samplePortfolio()

        try repository.save(portfolio)
        let loaded = try #require(try repository.load())

        #expect(loaded == portfolio)
        #expect(loaded.positions[thyao]?.averageCost == portfolio.positions[thyao]?.averageCost)
        #expect(loaded.startingCash == Money(100_000))
    }

    @Test func saveOverwritesPreviousFile() throws {
        let repository = FilePortfolioRepository(fileURL: temporaryFile())
        try repository.save(try samplePortfolio())

        try repository.save(Portfolio(cash: Money(5)))

        #expect(try repository.load() == Portfolio(cash: Money(5)))
    }

    /// Tutarlar JSON'da sayı değil metin: Double'a dönüşüp kuruş kaybetmesin.
    @Test func moneyIsStoredAsText() throws {
        let file = temporaryFile()
        try FilePortfolioRepository(fileURL: file).save(try samplePortfolio())

        let json = try String(contentsOf: file, encoding: .utf8)
        #expect(json.contains("\"price\" : \"287.55\""))
        #expect(json.contains("\"schemaVersion\" : 1"))
    }

    @Test func corruptedFileThrows() throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file)

        #expect(throws: (any Error).self) { try FilePortfolioRepository(fileURL: file).load() }
    }

    /// Daha yeni bir uygulama sürümünün yazdığı dosya: yanlış okumak yerine açıkça reddet.
    @Test func newerSchemaVersionIsRejected() throws {
        var snapshot = PortfolioSnapshot(Portfolio(cash: Money(1)))
        snapshot.schemaVersion = 99

        #expect(throws: PersistenceError.unsupportedSchemaVersion(99)) { try snapshot.toPortfolio() }
    }

    @Test func invalidAmountIsRejected() throws {
        var snapshot = PortfolioSnapshot(Portfolio(cash: Money(1)))
        snapshot.cash = "abc"

        #expect(throws: PersistenceError.invalidValue("abc")) { try snapshot.toPortfolio() }
    }
}

/// `PortfolioStore` + depo: DIP sayesinde testte dosya yerine bellek deposu.
struct PortfolioStorePersistenceTests {

    @Test func storeRestoresSavedPortfolioOnLaunch() async throws {
        let saved = try samplePortfolio()
        let store = PortfolioStore(repository: InMemoryPortfolioRepository(stored: saved))

        #expect(await store.currentPortfolio() == saved)
    }

    @Test func storeSavesAfterEveryTrade() async throws {
        let repository = InMemoryPortfolioRepository()
        let store = PortfolioStore(initialCash: Money(1_000), repository: repository)

        try await store.execute(Order(symbol: thyao, side: .buy, quantity: 2), at: quote("100"))

        #expect(repository.saveCount == 1)
        #expect(try repository.load()?.positions[thyao]?.quantity == 2)
    }

    /// Kayıt başarısız olsa bile işlem bellekte geçerli; kullanıcı alımını kaybetmez.
    @Test func failedSaveKeepsTradeInMemory() async throws {
        let repository = InMemoryPortfolioRepository()
        repository.failsOnSave = true
        let store = PortfolioStore(initialCash: Money(1_000), repository: repository)

        try await store.execute(Order(symbol: thyao, side: .buy, quantity: 2), at: quote("100"))

        #expect(await store.currentPortfolio().positions[thyao]?.quantity == 2)
        #expect(await store.lastSaveError != nil)
    }

    @Test func resetReturnsToStartingCashAndSaves() async throws {
        let repository = InMemoryPortfolioRepository()
        let store = PortfolioStore(initialCash: Money(1_000), repository: repository)
        try await store.execute(Order(symbol: thyao, side: .buy, quantity: 2), at: quote("100"))

        await store.reset()

        #expect(await store.currentPortfolio() == Portfolio(cash: Money(1_000)))
        #expect(try repository.load() == Portfolio(cash: Money(1_000)))
    }

    /// Gerçek dosyayla uçtan uca: işlem yap, "uygulamayı kapat", yeniden aç.
    @Test func tradesSurviveRelaunchWithFileRepository() async throws {
        let file = temporaryFile()
        let firstLaunch = PortfolioStore(initialCash: Money(1_000), repository: FilePortfolioRepository(fileURL: file))
        try await firstLaunch.execute(Order(symbol: thyao, side: .buy, quantity: 3), at: quote("100"))

        let secondLaunch = PortfolioStore(initialCash: Money(1_000), repository: FilePortfolioRepository(fileURL: file))

        #expect(await secondLaunch.currentPortfolio().positions[thyao]?.quantity == 3)
        #expect(await secondLaunch.currentPortfolio().cash == Money(700))
    }
}

struct PortfolioTotalsTests {

    @Test func totalProfitLossIsMeasuredFromStartingCash() throws {
        var portfolio = Portfolio(cash: Money(1_000))
        try portfolio.execute(Order(symbol: thyao, side: .buy, quantity: 2), at: quote("100"))

        // Nakit 800 + 2 × 130 = 1.060 → +60
        #expect(portfolio.totalProfitLoss(prices: [thyao: Money(130)]) == Money(60))
    }
}
