import Foundation
import Domain

/// Fiyatın yönü. Renk kararı enum olarak taşınır; `UIColor`'a çevirmek View'ın işi.
enum PriceTrend {
    case up, down, flat

    init(changePercent: Decimal) {
        if changePercent > 0 {
            self = .up
        } else if changePercent < 0 {
            self = .down
        } else {
            self = .flat
        }
    }
}

/// Presenter'ların ortak formatlama kuralları. UIKit bilmez.
/// Birden fazla sahne aynı biçimi kullanınca tek yerde durması tutarlılık sağlar.
enum PriceFormatting {

    /// "₺1.234,50": Türk lirası, Türkçe sayı biçimi.
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.currencyCode = "TRY"
        return formatter
    }()

    /// "%1,14": değer zaten yüzde olduğu için 100 ile çarpılmaz (multiplier = 1).
    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.multiplier = 1
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter
    }()

    static func price(_ money: Money) -> String {
        priceFormatter.string(from: money.amount as NSDecimalNumber) ?? "—"
    }

    /// İşaretli yüzde: "+%1,14", "-%0,52", "%0,00".
    static func changePercent(_ percent: Decimal) -> String {
        let text = percentFormatter.string(from: percent as NSDecimalNumber) ?? ""
        return percent > 0 ? "+" + text : text
    }

    /// Çizim için Double yeterli; hassas para hesabı burada yapılmıyor.
    static func chartValue(_ money: Money) -> Double {
        NSDecimalNumber(decimal: money.amount).doubleValue
    }
}
