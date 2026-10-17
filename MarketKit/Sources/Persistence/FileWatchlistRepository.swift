import Foundation
import Domain

/// İzleme listesini cihazda bir JSON dosyasında saklar (portföy deposuyla aynı desen).
public final class FileWatchlistRepository: WatchlistRepository {

    /// Diskteki biçim: sıra önemli, isim de saklanır (çevrimdışıyken de gösterilebilsin).
    struct Snapshot: Codable, Equatable {
        static let currentSchemaVersion = 1
        var schemaVersion: Int
        var items: [Item]

        struct Item: Codable, Equatable {
            var symbol: String
            var name: String
        }
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultLocation() throws -> FileWatchlistRepository {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FileWatchlistRepository(fileURL: directory.appendingPathComponent("watchlist.json"))
    }

    public func load() throws -> [Instrument]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL))
        guard snapshot.schemaVersion <= Snapshot.currentSchemaVersion else {
            throw PersistenceError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        return snapshot.items.map { Instrument(symbol: Symbol($0.symbol), name: $0.name) }
    }

    public func save(_ instruments: [Instrument]) throws {
        let snapshot = Snapshot(
            schemaVersion: Snapshot.currentSchemaVersion,
            items: instruments.map { Snapshot.Item(symbol: $0.symbol.rawValue, name: $0.name) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
