/// Sanal hesap: nakit, pozisyonlar ve işlem geçmişi.
///
/// Değer tipi (struct): her değişiklik yeni bir kopya üretir. Paylaşılan, eşzamanlı
/// erişilen hali Phase 7'de bir actor (`PortfolioStore`) içinde tutulacak.
public struct Portfolio: Sendable, Equatable {

    public private(set) var cash: Money
    /// Satılıp sıfırlanan pozisyonlar da burada kalır; gerçekleşen K/Z kaybolmasın diye.
    public private(set) var positions: [Symbol: Position]
    /// En eski işlem başta.
    public private(set) var trades: [Trade]

    public init(cash: Money) {
        self.cash = cash
        self.positions = [:]
        self.trades = []
    }

    /// Elde adet olan pozisyonlar, hisse koduna göre sıralı.
    public var openPositions: [Position] {
        positions.values
            .filter { $0.quantity > 0 }
            .sorted { $0.symbol.rawValue < $1.symbol.rawValue }
    }

    // MARK: - Emir

    /// Emri verilen fiyatla gerçekleştirir.
    /// Herhangi bir kontrol başarısız olursa hata fırlatır ve portföy değişmez.
    @discardableResult
    public mutating func execute(_ order: Order, at quote: Quote) throws -> Trade {
        precondition(order.symbol == quote.symbol, "Emir ve fiyat farklı hisselere ait")

        guard let price = order.type.executionPrice(for: order.side, quote: quote) else {
            throw TradingError.orderNotFillable
        }

        // Kurallar Position'da; değişiklikleri önce bir kopyada yapıyoruz.
        // Hepsi başarılı olursa kaydediyoruz, böylece yarım kalan işlem olmaz.
        var position = positions[order.symbol] ?? Position(symbol: order.symbol)
        var newCash = cash
        let total = price * order.quantity

        switch order.side {
        case .buy:
            try position.buy(quantity: order.quantity, price: price)
            guard total <= cash else {
                throw TradingError.insufficientCash(available: cash, required: total)
            }
            newCash = cash - total
        case .sell:
            try position.sell(quantity: order.quantity, price: price)
            newCash = cash + total
        }

        let trade = Trade(
            symbol: order.symbol,
            side: order.side,
            quantity: order.quantity,
            price: price,
            date: quote.timestamp
        )
        positions[order.symbol] = position
        cash = newCash
        trades.append(trade)
        return trade
    }

    // MARK: - Değerleme

    /// Pozisyonların piyasa değeri. Fiyatı bilinmeyen hisse için maliyet kullanılır.
    public func positionsValue(prices: [Symbol: Money]) -> Money {
        openPositions.reduce(.zero) { sum, position in
            sum + position.marketValue(at: prices[position.symbol] ?? position.averageCost)
        }
    }

    /// Toplam hesap değeri: nakit + pozisyonlar.
    public func totalValue(prices: [Symbol: Money]) -> Money {
        cash + positionsValue(prices: prices)
    }

    /// Tüm açık pozisyonların gerçekleşmemiş K/Z'si.
    public func unrealizedPnL(prices: [Symbol: Money]) -> Money {
        openPositions.reduce(.zero) { sum, position in
            sum + position.unrealizedPnL(at: prices[position.symbol] ?? position.averageCost)
        }
    }

    /// Tüm satışlardan gerçekleşen K/Z.
    public var realizedPnL: Money {
        positions.values.reduce(.zero) { $0 + $1.realizedPnL }
    }
}

