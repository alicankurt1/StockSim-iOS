import Foundation

/// Bir hissede elde tutulan pozisyon: kaç adet, birim başına ortalama ne kadara alındı,
/// satışlardan ne kadar kâr/zarar gerçekleşti.
///
/// Kurallar (komisyon yok):
/// - Alım: ortalama maliyet ağırlıklı ortalamayla güncellenir.
///   ör. 10 adet @100 + 10 adet @120 → 20 adet, ortalama 110
/// - Satış: ortalama maliyet DEĞİŞMEZ; satılan kısmın kârı/zararı gerçekleşir.
///   ör. ort. 100, 4 adet @130 satış → gerçekleşen K/Z +120
/// - Hepsi satılınca adet 0, ortalama maliyet sıfırlanır; gerçekleşen K/Z kalır.
public struct Position: Hashable, Sendable {

    public let symbol: Symbol
    public private(set) var quantity: Int
    /// Birim başına ortalama maliyet.
    public private(set) var averageCost: Money
    /// Satışlardan gerçekleşmiş toplam kâr/zarar.
    public private(set) var realizedPnL: Money

    /// Boş pozisyon: henüz alım yok.
    public init(symbol: Symbol) {
        self.symbol = symbol
        self.quantity = 0
        self.averageCost = .zero
        self.realizedPnL = .zero
    }

    // MARK: - Hesaplanan değerler

    /// Toplam maliyet: ortalama maliyet × adet.
    public var costBasis: Money {
        averageCost * quantity
    }

    /// Verilen fiyattan pozisyonun piyasa değeri.
    public func marketValue(at price: Money) -> Money {
        price * quantity
    }

    /// Henüz satılmamış adetlerin kâr/zararı: piyasa değeri − toplam maliyet.
    public func unrealizedPnL(at price: Money) -> Money {
        marketValue(at: price) - costBasis
    }

    // MARK: - Değiştiren işlemler

    /// Alım: adet artar, ortalama maliyet ağırlıklı ortalamayla güncellenir.
    /// - Throws: `TradingError.invalidQuantity` adet ≤ 0 ise.
    public mutating func buy(quantity: Int, price: Money) throws {
        // Önce kontrol, sonra değişiklik: hata durumunda pozisyon bozulmaz.
        guard quantity > 0 else { throw TradingError.invalidQuantity }

        // Ağırlıklı ortalama: (eski toplam maliyet + yeni alımın maliyeti) / yeni adet
        let newQuantity = self.quantity + quantity
        let totalCost = costBasis + price * quantity
        averageCost = Money(totalCost.amount / Decimal(newQuantity))
        self.quantity = newQuantity
    }

    /// Satış: adet azalır, ortalama maliyet aynı kalır, satılan kısmın K/Z'si gerçekleşir.
    /// - Throws: `invalidQuantity` adet ≤ 0 ise; `insufficientQuantity` eldekinden fazlaysa.
    ///   Hata durumunda pozisyon değişmez.
    public mutating func sell(quantity: Int, price: Money) throws {
        guard quantity > 0 else { throw TradingError.invalidQuantity }
        guard quantity <= self.quantity else {
            throw TradingError.insufficientQuantity(available: self.quantity, requested: quantity)
        }

        // Satılan her adet için (satış fiyatı − ortalama maliyet) kadar K/Z gerçekleşir.
        realizedPnL = realizedPnL + (price - averageCost) * quantity
        self.quantity -= quantity

        // Elde hiç kalmadıysa ortalama maliyetin anlamı kalmaz.
        if self.quantity == 0 {
            averageCost = .zero
        }
    }
}
