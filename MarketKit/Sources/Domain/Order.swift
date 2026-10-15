/// Alım mı satım mı.
public enum OrderSide: Sendable, Hashable, Codable {
    case buy
    case sell
}

/// Emir tipi: bir emrin hangi fiyattan gerçekleşeceğine karar verir.
///
/// OCP (Open/Closed): `Portfolio` sadece bu protokolü bilir. Yeni bir emir tipi
/// (ör. limit emri) eklemek için yeni bir tip yazmak yeterli; `Portfolio` değişmez.
public protocol OrderType: Sendable {
    /// Emir şu anki fiyattan gerçekleşebiliyorsa gerçekleşme fiyatı, gerçekleşemiyorsa `nil`.
    func executionPrice(for side: OrderSide, quote: Quote) -> Money?
}

/// Piyasa emri: her zaman anlık fiyattan gerçekleşir.
public struct MarketOrder: OrderType {
    public init() {}

    public func executionPrice(for side: OrderSide, quote: Quote) -> Money? {
        quote.price
    }
}

/// Kullanıcının verdiği emir: hangi hisse, alım/satım, kaç adet, hangi tip.
public struct Order: Sendable {
    public let symbol: Symbol
    public let side: OrderSide
    public let quantity: Int
    public let type: any OrderType

    public init(symbol: Symbol, side: OrderSide, quantity: Int, type: any OrderType = MarketOrder()) {
        self.symbol = symbol
        self.side = side
        self.quantity = quantity
        self.type = type
    }
}
