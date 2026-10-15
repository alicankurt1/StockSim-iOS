import Foundation
import Domain

/// Fiyat hareketi matematiği: geometrik Brown hareketi (GBM). Saf fonksiyonlar, test edilebilir.
///
/// Simülasyon `Double` ile yapılır (exp, log, karekök gerekiyor); fiyat dışarı
/// `Money` olarak çıkarken kuruşa yuvarlanır.
enum PriceModel {

    /// Bir adım sonraki fiyat: S · exp((μ − σ²/2)·Δt + σ·√Δt·Z)
    /// - Parameters:
    ///   - drift: μ, yıllık beklenen getiri (0,10 = %10)
    ///   - volatility: σ, yıllık oynaklık (0,40 = %40)
    ///   - dt: adımın yıl cinsinden uzunluğu
    ///   - z: standart normal rastgele sayı
    /// `exp` her zaman pozitif olduğu için fiyat asla sıfırın altına düşmez.
    static func nextPrice(_ price: Double, drift: Double, volatility: Double, dt: Double, z: Double) -> Double {
        price * exp(logReturn(drift: drift, volatility: volatility, dt: dt, z: z))
    }

    /// Bir adım ÖNCEKİ fiyat (geçmiş üretirken geriye doğru yürümek için).
    static func previousPrice(_ price: Double, drift: Double, volatility: Double, dt: Double, z: Double) -> Double {
        price / exp(logReturn(drift: drift, volatility: volatility, dt: dt, z: z))
    }

    private static func logReturn(drift: Double, volatility: Double, dt: Double, z: Double) -> Double {
        (drift - volatility * volatility / 2) * dt + volatility * dt.squareRoot() * z
    }

    /// Double fiyatı kuruşa yuvarlanmış Money'ye çevirir. Tam sayı üzerinden gittiği için
    /// Double → Decimal hassasiyet sorunu yaşanmaz.
    static func money(_ price: Double) -> Money {
        Money(Decimal(Int64((price * 100).rounded())) / 100)
    }
}
