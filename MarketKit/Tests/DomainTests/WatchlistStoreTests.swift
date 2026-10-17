import Foundation
import Testing
@testable import Domain

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let asels = Instrument(symbol: Symbol("ASELS"), name: "Aselsan")
private let aksa = Instrument(symbol: Symbol("AKSA"), name: "Aksa Akrilik")

/// Bellekte saklayan sahte depo.
private final class MemoryRepository: WatchlistRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Instrument]?
    init(_ stored: [Instrument]? = nil) { self.stored = stored }
    func load() throws -> [Instrument]? { lock.withLock { stored } }
    func save(_ instruments: [Instrument]) throws { lock.withLock { stored = instruments } }
}

struct WatchlistStoreTests {

    @Test func firstLaunchUsesDefaults() async {
        let store = WatchlistStore(defaults: [thyao, asels], repository: MemoryRepository())
        #expect(await store.current() == [thyao, asels])
    }

    @Test func savedListWinsOverDefaults() async {
        let store = WatchlistStore(defaults: [thyao, asels], repository: MemoryRepository([aksa]))
        #expect(await store.current() == [aksa])
    }

    @Test func addAppendsOnceAndSaves() async throws {
        let repository = MemoryRepository()
        let store = WatchlistStore(defaults: [thyao], repository: repository)

        await store.add(aksa)
        await store.add(aksa)   // ikinci kez eklenmez

        #expect(await store.current() == [thyao, aksa])
        #expect(try repository.load() == [thyao, aksa])
    }

    @Test func removeDeletesAndSaves() async throws {
        let repository = MemoryRepository()
        let store = WatchlistStore(defaults: [thyao, asels], repository: repository)

        await store.remove(thyao.symbol)

        #expect(await store.current() == [asels])
        #expect(try repository.load() == [asels])
    }

    @Test func reorderFollowsGivenOrder() async {
        let store = WatchlistStore(defaults: [thyao, asels, aksa])

        await store.reorder([aksa.symbol, thyao.symbol, asels.symbol])

        #expect(await store.current() == [aksa, thyao, asels])
    }

    @Test func changesStreamCurrentThenEachChange() async {
        let store = WatchlistStore(defaults: [thyao])
        var iterator = await store.changes().makeAsyncIterator()

        #expect(await iterator.next() == [thyao])
        await store.add(aksa)
        #expect(await iterator.next() == [thyao, aksa])
    }
}

struct BistDirectoryTests {

    /// Kod ya da isimde geçen hisseler; Türkçe harfler ve büyük/küçük harf yok sayılır.
    @Test(arguments: [
        ("aks", Set(["AKSA", "AKSEN"])),
        ("THY", Set(["THYAO"])),
        ("şişe", Set(["SISE"])),
        ("türk", Set(["THYAO", "TTKOM", "TCELL"])),   // "Türk Hava Yolları", "Türk Telekom", "Turkcell"
    ])
    func searchMatchesSymbolOrName(query: String, expected: Set<String>) {
        #expect(Set(BistDirectory.search(query).map(\.symbol.rawValue)) == expected)
    }

    /// Kodu sorguyla başlayanlar, sadece isminde geçenlerden önce gelir.
    @Test func symbolPrefixMatchesComeFirst() {
        // "ak": önce kodu "AK" ile başlayanlar (AKBNK, AKSA…), sonra sadece isminde geçenler.
        let results = BistDirectory.search("ak").map(\.symbol.rawValue)
        let firstNonPrefix = results.firstIndex { !$0.hasPrefix("AK") } ?? results.endIndex
        #expect(results[..<firstNonPrefix].allSatisfy { $0.hasPrefix("AK") })
        #expect(results[firstNonPrefix...].allSatisfy { !$0.hasPrefix("AK") })
    }

    @Test func emptyQueryReturnsNothing() {
        #expect(BistDirectory.search("   ").isEmpty)
    }

    @Test func directoryIncludesTheDefaultCatalog() {
        let symbols = Set(BistDirectory.instruments.map(\.symbol))
        #expect(BistCatalog.instruments.allSatisfy { symbols.contains($0.symbol) })
    }
}
