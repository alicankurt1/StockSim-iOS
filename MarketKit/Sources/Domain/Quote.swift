import Foundation

/// Bir hissenin belirli bir andaki fiyatı.
///
/// Günlük değişim saklanmaz, hesaplanır: tek doğruluk kaynağı `price` ve
/// `previousClose`. İkisini ayrı tutsaydık birbirleriyle çelişebilirlerdi.
public struct Quote: Hashable, Sendable {

    public let symbol: Symbol
    public let price: Money
    /// Önceki günün kapanış fiyatı; günlük değişim buna göre hesaplanır.
    public let previousClose: Money
    public let timestamp: Date

    public init(symbol: Symbol, price: Money, previousClose: Money, timestamp: Date) {
        self.symbol = symbol
        self.price = price
        self.previousClose = previousClose
        self.timestamp = timestamp
    }

    /// Günlük değişim tutarı (ör. +3,25 ₺).
    public var change: Money {
        price - previousClose
    }

    /// Günlük değişim yüzdesi (ör. 10 → %10). Yuvarlanmamış; Presenter yuvarlar.
    public var changePercent: Decimal {
        // Önceki kapanış sıfır (ya da geçersiz) ise bölme yapma.
        if previousClose.amount > 0 {
            change.amount / previousClose.amount * 100
        } else {
            0
        }
    }
}
