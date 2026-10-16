import CoreGraphics

/// Sparkline'ın saf matematiği: değerleri view içindeki noktalara çevirir.
///
/// UIKit bilmez; bu yüzden macOS'ta `swift test` ile test edilir. Çizimi yapan
/// `SparklineView` sadece bu noktaları birleştirir.
public enum SparklineGeometry {

    /// Değerleri `size` içine yerleştirir.
    /// - x: değerler soldan sağa eşit aralıklarla dizilir.
    /// - y: en büyük değer en üstte, en küçük en altta. UIKit'te y aşağı doğru
    ///   arttığı için ters çeviriyoruz.
    /// - `inset`: çizgi kalınlığı kenarlarda kırpılmasın diye bırakılan pay.
    /// - Hepsi aynı değerse (düz çizgi) dikeyde ortalanır.
    public static func points(for values: [Double], in size: CGSize, inset: CGFloat = 1) -> [CGPoint] {
        guard !values.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let drawable = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        let minValue = values.min()!
        let maxValue = values.max()!
        let range = maxValue - minValue
        // Tek değer varsa x'te ortaya koy; birden fazlaysa kenardan kenara yay.
        let stepX = values.count > 1 ? drawable.width / CGFloat(values.count - 1) : 0
        let startX = values.count > 1 ? drawable.minX : drawable.midX

        return values.enumerated().map { index, value in
            let x = startX + CGFloat(index) * stepX
            guard range > 0 else { return CGPoint(x: x, y: drawable.midY) }
            // 0 = en küçük, 1 = en büyük.
            let normalized = CGFloat((value - minValue) / range)
            let y = drawable.maxY - normalized * drawable.height
            return CGPoint(x: x, y: y)
        }
    }
}
