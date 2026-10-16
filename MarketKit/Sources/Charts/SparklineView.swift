#if canImport(UIKit)
import UIKit

/// Küçük fiyat grafiği: bir çizgi ve altında solan bir dolgu.
///
/// Çizim Core Animation katmanlarıyla yapılır, `draw(_:)` ile değil:
/// - `lineLayer` (CAShapeLayer): çizgiyi çizer.
/// - `fillLayer` (CAGradientLayer): renk → şeffaf dikey geçiş; `fillMask` ile sadece
///   çizginin altındaki alan görünür.
/// Katmanlar bir kez kurulur; değer değişince sadece `path` güncellenir (hücre reuse'ta ucuz).
public final class SparklineView: UIView {

    private let lineLayer = CAShapeLayer()
    private let fillLayer = CAGradientLayer()
    private let fillMask = CAShapeLayer()

    private var values: [Double] = []
    /// `UIColor` saklıyoruz: katmanlar `CGColor` ister ve açık/koyu mod değişince
    /// kendiliğinden güncellenmez; değişimde yeniden çözümlüyoruz.
    private var color: UIColor = .systemBlue

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        fillLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fillLayer.endPoint = CGPoint(x: 0.5, y: 1)
        fillLayer.mask = fillMask
        layer.addSublayer(fillLayer)

        lineLayer.fillColor = nil
        lineLayer.lineWidth = 1.5
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round
        layer.addSublayer(lineLayer)

        observeAppearanceChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Değerleri ve rengi ayarlar. Aynı view farklı hisselerle tekrar tekrar kullanılabilir.
    public func setValues(_ values: [Double], color: UIColor) {
        self.values = values
        self.color = color
        updateColors()
        updatePaths()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Boyut değişince (ilk yerleşim, döndürme) yolları yeni boyuta göre çiz.
        updatePaths()
    }

    // MARK: - Çizim

    private func updatePaths() {
        let points = SparklineGeometry.points(for: values, in: bounds.size, inset: lineLayer.lineWidth)

        // CALayer özellik değişikliklerini varsayılan olarak 0,25 sn animasyonla yapar.
        // Reuse'ta önceki hissenin çizgisinden "kayarak" gelmesin diye kapatıyoruz.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lineLayer.frame = bounds
        fillLayer.frame = bounds
        fillMask.frame = bounds

        guard let first = points.first, let last = points.last else {
            lineLayer.path = nil
            fillMask.path = nil
            CATransaction.commit()
            return
        }

        let line = UIBezierPath()
        line.move(to: first)
        points.dropFirst().forEach { line.addLine(to: $0) }
        lineLayer.path = line.cgPath

        // Dolgu: çizgi + sağ alt köşe + sol alt köşe → kapalı şekil.
        let fill = UIBezierPath(cgPath: line.cgPath)
        fill.addLine(to: CGPoint(x: last.x, y: bounds.maxY))
        fill.addLine(to: CGPoint(x: first.x, y: bounds.maxY))
        fill.close()
        fillMask.path = fill.cgPath
        CATransaction.commit()
    }

    private func updateColors() {
        let resolved = color.resolvedColor(with: traitCollection)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lineLayer.strokeColor = resolved.cgColor
        fillLayer.colors = [resolved.withAlphaComponent(0.28).cgColor, resolved.withAlphaComponent(0).cgColor]
        CATransaction.commit()
    }

    // MARK: - Açık/koyu mod

    /// iOS 17 ile yeni API geldi; iOS 16'da eski yöntem kullanılır.
    /// `#available`: çalışma anında sürümü kontrol eder ve yeni API'yi sadece destekleyen cihazda çağırır.
    private func observeAppearanceChanges() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SparklineView, _: UITraitCollection) in
                view.updateColors()
            }
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ cihazlarda yukarıdaki kayıt zaten çalışıyor; iki kez güncellemeyelim.
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }
}
#endif
