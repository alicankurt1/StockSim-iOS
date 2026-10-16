import Foundation
import Domain

/// Hesabı cihazda tek bir JSON dosyasında saklar.
///
/// - Atomik yazma: önce geçici bir dosyaya yazılır, sonra tek hamlede yerine konur.
///   Yazma sırasında uygulama kapanırsa eski dosya sağlam kalır; yarım dosya oluşmaz.
/// - `Sendable`: sadece değişmeyen (`let`) alanlar var, farklı thread'lerden güvenle kullanılır.
public final class FilePortfolioRepository: PortfolioRepository {

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Uygulamanın kendi "Application Support" klasöründe varsayılan konum.
    public static func defaultLocation() throws -> FilePortfolioRepository {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FilePortfolioRepository(fileURL: directory.appendingPathComponent("portfolio.json"))
    }

    public func load() throws -> Portfolio? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(PortfolioSnapshot.self, from: data).toPortfolio()
    }

    public func save(_ portfolio: Portfolio) throws {
        let data = try Self.encoder.encode(PortfolioSnapshot(portfolio))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // Okunabilir ve her seferinde aynı sırada: diff alması ve hata ayıklaması kolay.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// Bellekte saklayan sahte depo: testler ve önizlemeler için (LSP: dosya deposunun yerine geçer).
public final class InMemoryPortfolioRepository: PortfolioRepository, @unchecked Sendable {

    // `@unchecked Sendable`: değişen durum var ama bir kilitle korunuyor; derleyici bunu
    // kendisi doğrulayamadığı için güvenceyi biz veriyoruz. Sadece testlerde kullanılıyor.
    private let lock = NSLock()
    private var stored: Portfolio?
    public private(set) var saveCount = 0
    public var failsOnSave = false

    public init(stored: Portfolio? = nil) {
        self.stored = stored
    }

    public func load() throws -> Portfolio? {
        lock.withLock { stored }
    }

    public func save(_ portfolio: Portfolio) throws {
        try lock.withLock {
            if failsOnSave { throw CocoaError(.fileWriteUnknown) }
            stored = portfolio
            saveCount += 1
        }
    }
}
