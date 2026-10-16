import CoreGraphics

/// Veri ↔ ekran noktası dönüşümü. Büyük grafiklerin (çizgi, mum) ortak matematiği.
///
/// - x: indeks → yatay konum. Noktalar `rect` içinde eşit aralıklı.
/// - y: değer → dikey konum. Üstte ve altta `padding` kadar pay bırakılır ki
///   en yüksek/en düşük nokta kenara yapışmasın.
/// - Ters yön (`index(nearestTo:)`, `value(atY:)`) parmakla dokunulan noktayı bulmak için
///   (Phase 6: crosshair).
///
/// UIKit bilmez; macOS'ta test edilir.
public struct ChartScale: Equatable {

    public let rect: CGRect
    public let count: Int
    /// Pay eklenmiş değer aralığı (en alt → en üst).
    public let minValue: Double
    public let maxValue: Double

    /// - Parameter padding: aralığın yüzde kaçı kadar üstte ve altta boşluk (0,08 = %8).
    public init(values: [Double], count: Int, rect: CGRect, padding: Double = 0.08) {
        self.rect = rect
        self.count = count

        let low = values.min() ?? 0
        let high = values.max() ?? 0
        // Düz seride aralık 0 olur; bölme hatası olmasın diye yapay bir aralık veriyoruz.
        let span = high > low ? high - low : max(abs(high) * 0.01, 1)
        let center = (high + low) / 2
        let halfSpan = span / 2 * (1 + 2 * padding)
        self.minValue = center - halfSpan
        self.maxValue = center + halfSpan
    }

    /// İki nokta arasındaki yatay mesafe.
    public var step: CGFloat {
        count > 1 ? rect.width / CGFloat(count - 1) : 0
    }

    public func x(at index: Int) -> CGFloat {
        count > 1 ? rect.minX + CGFloat(index) * step : rect.midX
    }

    /// UIKit'te y aşağı doğru artar: büyük değer küçük y (üstte).
    public func y(for value: Double) -> CGFloat {
        let normalized = CGFloat((value - minValue) / (maxValue - minValue))
        return rect.maxY - normalized * rect.height
    }

    /// Bir y konumundaki değer (`y(for:)`'un tersi).
    public func value(atY y: CGFloat) -> Double {
        let normalized = Double((rect.maxY - y) / rect.height)
        return minValue + normalized * (maxValue - minValue)
    }

    /// Bir x konumuna en yakın noktanın indeksi; grafiğin dışına taşan dokunuşlar kenara sabitlenir.
    public func index(nearestTo x: CGFloat) -> Int {
        guard count > 1, step > 0 else { return 0 }
        let raw = ((x - rect.minX) / step).rounded()
        return min(max(Int(raw), 0), count - 1)
    }
}
