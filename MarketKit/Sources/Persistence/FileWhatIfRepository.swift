import Foundation
import Domain

/// Takip edilen senaryoları JSON dosyasında saklar. Para metin olarak (kuruş kaybı olmasın).
public final class FileWhatIfRepository: WhatIfRepository {

    struct Snapshot: Codable, Equatable {
        static let currentSchemaVersion = 1
        var schemaVersion: Int
        var scenarios: [Record]

        struct Record: Codable, Equatable {
            var id: UUID
            var symbol: String
            var name: String
            var amount: String
            var startDate: Date
            var entryPrice: String
        }
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultLocation() throws -> FileWhatIfRepository {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FileWhatIfRepository(fileURL: directory.appendingPathComponent("what-if.json"))
    }

    public func load() throws -> [WhatIfScenario]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(Snapshot.self, from: Data(contentsOf: fileURL))
        guard snapshot.schemaVersion <= Snapshot.currentSchemaVersion else {
            throw PersistenceError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        return try snapshot.scenarios.map { record in
            WhatIfScenario(
                id: record.id,
                instrument: Instrument(symbol: Symbol(record.symbol), name: record.name),
                amount: try Self.money(record.amount),
                startDate: record.startDate,
                entryPrice: try Self.money(record.entryPrice)
            )
        }
    }

    public func save(_ scenarios: [WhatIfScenario]) throws {
        let snapshot = Snapshot(schemaVersion: Snapshot.currentSchemaVersion, scenarios: scenarios.map {
            Snapshot.Record(
                id: $0.id,
                symbol: $0.instrument.symbol.rawValue,
                name: $0.instrument.name,
                amount: $0.amount.amount.description,
                startDate: $0.startDate,
                entryPrice: $0.entryPrice.amount.description
            )
        })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    private static func money(_ text: String) throws -> Money {
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw PersistenceError.invalidValue(text)
        }
        return Money(value)
    }
}
