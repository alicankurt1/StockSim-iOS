import Foundation
import Testing
import Domain
@testable import Persistence

struct FileWatchlistRepositoryTests {

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("StockSimTests-\(UUID().uuidString)")
            .appendingPathComponent("watchlist.json")
    }

    @Test func missingFileLoadsNil() throws {
        #expect(try FileWatchlistRepository(fileURL: temporaryFile()).load() == nil)
    }

    /// Sıra ve isimler (Türkçe karakterler dahil) korunur.
    @Test func roundTripKeepsOrderAndNames() throws {
        let repository = FileWatchlistRepository(fileURL: temporaryFile())
        let list = [
            Instrument(symbol: Symbol("SISE"), name: "Şişecam"),
            Instrument(symbol: Symbol("AKSA"), name: "Aksa Akrilik"),
        ]

        try repository.save(list)

        #expect(try repository.load() == list)
    }

    /// Uygulama kapanıp açılınca liste geri gelir (store + gerçek dosya).
    @Test func storeSurvivesRelaunch() async throws {
        let file = temporaryFile()
        let first = WatchlistStore(defaults: BistCatalog.instruments, repository: FileWatchlistRepository(fileURL: file))
        await first.add(Instrument(symbol: Symbol("AKSA"), name: "Aksa Akrilik"))
        await first.remove(Symbol("THYAO"))

        let second = WatchlistStore(defaults: BistCatalog.instruments, repository: FileWatchlistRepository(fileURL: file))
        let symbols = await second.current().map(\.symbol.rawValue)

        #expect(symbols.last == "AKSA")
        #expect(!symbols.contains("THYAO"))
    }
}

struct FileWhatIfRepositoryTests {

    /// Senaryolar (kesirli bölmeye yol açan tutarlar dahil) birebir geri gelir.
    @Test func roundTrip() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("StockSimTests-\(UUID().uuidString)")
            .appendingPathComponent("what-if.json")
        let repository = FileWhatIfRepository(fileURL: file)
        let scenarios = [WhatIfScenario(
            instrument: Instrument(symbol: Symbol("SISE"), name: "Şişecam"),
            amount: Money(100_000),
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            entryPrice: Money(Decimal(string: "41.72")!)
        )]

        try repository.save(scenarios)

        #expect(try repository.load() == scenarios)
    }
}
