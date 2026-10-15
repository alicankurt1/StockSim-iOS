import Foundation

/// Gerçekleşmiş bir işlem; işlem geçmişinin bir satırı.
public struct Trade: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let symbol: Symbol
    public let side: OrderSide
    public let quantity: Int
    /// Birim gerçekleşme fiyatı.
    public let price: Money
    public let date: Date

    public init(id: UUID = UUID(), symbol: Symbol, side: OrderSide, quantity: Int, price: Money, date: Date) {
        self.id = id
        self.symbol = symbol
        self.side = side
        self.quantity = quantity
        self.price = price
        self.date = date
    }

    /// İşlem tutarı: fiyat × adet.
    public var total: Money { price * quantity }
}
