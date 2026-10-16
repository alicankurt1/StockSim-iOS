import CoreGraphics

/// Grafikteki bir nokta: bir zaman aralığının açılış, en yüksek, en düşük, kapanış değeri.
/// Çizgi grafik sadece `close`'u, mum grafik dördünü de kullanır.
public struct ChartPoint: Equatable, Sendable {
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double

    public init(open: Double, high: Double, low: Double, close: Double) {
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }

    public var isRising: Bool { close >= open }
}

public struct ChartData: Equatable, Sendable {
    public let points: [ChartPoint]
    /// Kesikli referans çizgisi (ör. önceki kapanış). `nil` ise çizilmez.
    public let baseline: Double?

    public init(points: [ChartPoint], baseline: Double? = nil) {
        self.points = points
        self.baseline = baseline
    }
}

/// Mumun geometrisi: saf matematik, macOS'ta test edilir.
public enum CandleGeometry {

    /// Mum gövdesinin genişliği: iki mum arası mesafenin %60'ı; çok ince ya da çok kalın olmasın.
    public static func bodyWidth(step: CGFloat) -> CGFloat {
        min(max(step * 0.6, 1), 14)
    }

    /// Gövde: açılış ile kapanış arası dikdörtgen. Açılış = kapanış ise en az 1 pt yükseklik.
    public static func bodyRect(open: Double, close: Double, x: CGFloat, width: CGFloat, scale: ChartScale) -> CGRect {
        let top = scale.y(for: max(open, close))
        let bottom = scale.y(for: min(open, close))
        return CGRect(x: x - width / 2, y: top, width: width, height: max(bottom - top, 1))
    }

    /// Fitil: en yüksekten en düşüğe dikey çizgi.
    public static func wick(high: Double, low: Double, x: CGFloat, scale: ChartScale) -> (top: CGPoint, bottom: CGPoint) {
        (CGPoint(x: x, y: scale.y(for: high)), CGPoint(x: x, y: scale.y(for: low)))
    }
}

/// Dokunulan x'e en yakın noktayı bulur: ikili arama (binary search).
///
/// Neden ikili arama? Noktalar soldan sağa sıralı. Hepsini tek tek gezmek O(n);
/// her adımda aralığı ikiye bölmek O(log n). 1 yıllık günlük veride (~250 nokta)
/// her parmak hareketinde 250 yerine ~8 karşılaştırma.
public enum ChartHitTest {

    public static func nearestIndex(in sortedXs: [CGFloat], to x: CGFloat) -> Int? {
        guard !sortedXs.isEmpty else { return nil }
        var low = 0
        var high = sortedXs.count - 1
        while low < high {
            let middle = (low + high) / 2
            if sortedXs[middle] < x {
                low = middle + 1
            } else {
                high = middle
            }
        }
        // `low`: x'ten büyük ya da eşit ilk nokta. Bir öncekiyle kıyaslayıp yakın olanı seç.
        if low > 0, abs(sortedXs[low - 1] - x) <= abs(sortedXs[low] - x) {
            return low - 1
        }
        return low
    }
}
