import Foundation
import Domain

/// Diskteki JSON'un biçimi (DTO: Data Transfer Object).
///
/// Neden Domain tiplerini doğrudan `Codable` yapmadık?
/// - Domain, depolama biçimini bilmesin (SRP). Domain'de bir alanın adı değişince
///   eski kayıtlar bozulmasın; eşleme burada yapılır.
/// - `schemaVersion`: biçim değişirse eski dosyalar tanınır ve dönüştürülebilir (migration).
/// - Para `String` olarak saklanır: JSON sayıları `Double` üzerinden okunabildiği için
///   `Decimal`'in kuruş hassasiyeti kaybolabilir. "287.50" metni ise birebir geri gelir.
struct PortfolioSnapshot: Codable, Equatable {

    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var startingCash: String
    var cash: String
    var positions: [PositionRecord]
    var trades: [TradeRecord]

    struct PositionRecord: Codable, Equatable {
        var symbol: String
        var quantity: Int
        var averageCost: String
        var realizedPnL: String
    }

    struct TradeRecord: Codable, Equatable {
        var id: UUID
        var symbol: String
        var side: String
        var quantity: Int
        var price: String
        var date: Date
    }
}

enum PersistenceError: Error, Equatable {
    /// Dosya bu uygulama sürümünden daha yeni bir biçimde yazılmış.
    case unsupportedSchemaVersion(Int)
    /// Bir değer okunamadı (ör. "abc" bir tutar değil).
    case invalidValue(String)
}

// MARK: - Domain ↔ DTO

extension PortfolioSnapshot {

    init(_ portfolio: Portfolio) {
        schemaVersion = Self.currentSchemaVersion
        startingCash = portfolio.startingCash.amount.description
        cash = portfolio.cash.amount.description
        positions = portfolio.positions.values
            .sorted { $0.symbol.rawValue < $1.symbol.rawValue }
            .map { PositionRecord(
                symbol: $0.symbol.rawValue,
                quantity: $0.quantity,
                averageCost: $0.averageCost.amount.description,
                realizedPnL: $0.realizedPnL.amount.description
            ) }
        trades = portfolio.trades.map { TradeRecord(
            id: $0.id,
            symbol: $0.symbol.rawValue,
            side: $0.side == .buy ? "buy" : "sell",
            quantity: $0.quantity,
            price: $0.price.amount.description,
            date: $0.date
        ) }
    }

    func toPortfolio() throws -> Portfolio {
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw PersistenceError.unsupportedSchemaVersion(schemaVersion)
        }
        return Portfolio(
            startingCash: try money(startingCash),
            cash: try money(cash),
            positions: try positions.map { record in
                Position(
                    symbol: Symbol(record.symbol),
                    quantity: record.quantity,
                    averageCost: try money(record.averageCost),
                    realizedPnL: try money(record.realizedPnL)
                )
            },
            trades: try trades.map { record in
                guard let side: OrderSide = record.side == "buy" ? .buy : record.side == "sell" ? .sell : nil else {
                    throw PersistenceError.invalidValue(record.side)
                }
                return Trade(
                    id: record.id,
                    symbol: Symbol(record.symbol),
                    side: side,
                    quantity: record.quantity,
                    price: try money(record.price),
                    date: record.date
                )
            }
        )
    }

    private func money(_ text: String) throws -> Money {
        // `en_US_POSIX`: ondalık ayırıcı her cihazda nokta. Türkçe cihazda "287,50" beklenmesin.
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw PersistenceError.invalidValue(text)
        }
        return Money(value)
    }
}
