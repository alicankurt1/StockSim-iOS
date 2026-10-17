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
