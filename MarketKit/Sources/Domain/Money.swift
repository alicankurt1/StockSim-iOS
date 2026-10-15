import Foundation

/// Türk lirası cinsinden para miktarı.
///
/// Neden `Double` değil de `Decimal`? `Double` ikili (binary) kesir tutar; 0,1 gibi
/// ondalık sayıları tam gösteremez. Para hesabında bu küçük hatalar birikir.
/// `Decimal` ondalık tabanda tutar, kuruş kaybı olmaz.
///
/// Yuvarlama burada yapılmaz: tam hassasiyet saklanır, ekrana basarken Presenter yuvarlar.

public struct Money: Hashable, Comparable, Sendable {

    public let amount: Decimal

    public init(_ amount: Decimal) {
        self.amount = amount
    }

    public static let zero = Money(0)

    // MARK: - Aritmetik

    public static func + (lhs: Money, rhs: Money) -> Money {
        return Money(lhs.amount + rhs.amount)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        return Money(lhs.amount - rhs.amount)
    }

    /// Birim fiyat × adet (ör. 287,50 ₺ × 10 lot).
    public static func * (lhs: Money, rhs: Int) -> Money {
        return Money(lhs.amount * Decimal(rhs))
    }

    // MARK: - Comparable

    public static func < (lhs: Money, rhs: Money) -> Bool {
        return lhs.amount < rhs.amount
    }
}
