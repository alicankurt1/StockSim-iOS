import Foundation

/// Bir zaman aralığının fiyat özeti (OHLC): açılış, en yüksek, en düşük, kapanış.
/// Mum grafiğinde her mum bir `Candle`.
public struct Candle: Hashable, Sendable {

    /// Aralığın başlangıç zamanı.
    public let date: Date
    public let open: Money
    public let high: Money
    public let low: Money
    public let close: Money

    public init(date: Date, open: Money, high: Money, low: Money, close: Money) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }

    /// Yükselen mum mu? (Grafikte yeşil çizilecek.)
    /// Açılış ile kapanış eşitse de yükselen sayıyoruz.
    public var isBullish: Bool {
        // Money Comparable olduğu için doğrudan karşılaştırılabilir.
        close >= open
    }
}
