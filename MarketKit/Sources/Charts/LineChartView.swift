#if canImport(UIKit)
import UIKit

/// Çizgi grafiğin verisi.
public struct LineChartData: Equatable {
    public let values: [Double]
    /// Kesikli referans çizgisi (ör. önceki kapanış). `nil` ise çizilmez.
    public let baseline: Double?

    public init(values: [Double], baseline: Double? = nil) {
        self.values = values
        self.baseline = baseline
    }
}

/// Büyük çizgi grafik.
///
/// İki çizim yöntemini bilerek birlikte kullanıyor:
/// - **Arka plan ızgarası `draw(_:)` ile (Core Graphics):** nadiren değişir (sadece boyut ya da
///   tema değişince). UIKit, açık/koyu mod değişiminde `draw` olan view'ı kendisi yeniden çizer.
/// - **Fiyat çizgisi `CAShapeLayer` ile (Core Animation):** her saniye değişir; sadece `path`
///   güncellenir, boyama GPU'da. Aralık değişince çizgi soldan sağa "çizilerek" gelir (`strokeEnd`).
public final class LineChartView: UIView {

    public var gridColor: UIColor = .separator {
        didSet { setNeedsDisplay() }
    }

    private let lineLayer = CAShapeLayer()
    private let fillLayer = CAGradientLayer()
    private let fillMask = CAShapeLayer()
    private let baselineLayer = CAShapeLayer()

    private var data = LineChartData(values: [])
    private var color: UIColor = .systemBlue

    /// İçerik alanı: çizginin kenarlarda kırpılmaması için küçük pay.
    private var plotRect: CGRect { bounds.insetBy(dx: 2, dy: 4) }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        // Boyut değişince `draw(_:)` tekrar çağrılsın (ızgara yeni boyuta göre).
        contentMode = .redraw

        fillLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fillLayer.endPoint = CGPoint(x: 0.5, y: 1)
        fillLayer.mask = fillMask
        layer.addSublayer(fillLayer)

        baselineLayer.fillColor = nil
        baselineLayer.lineWidth = 1
        baselineLayer.lineDashPattern = [3, 4]
        layer.addSublayer(baselineLayer)

        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round
        layer.addSublayer(lineLayer)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: LineChartView, _: UITraitCollection) in
                view.updateColors()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Veriyi ve rengi ayarlar.
    /// - Parameter animated: `true` ise çizgi soldan sağa çizilerek gelir (aralık değişimi);
    ///   canlı fiyat güncellemelerinde `false` verilir.
    public func setData(_ data: LineChartData, color: UIColor, animated: Bool) {
        self.data = data
        self.color = color
        updateColors()
        updatePaths()
        if animated { animateDrawing() }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updatePaths()
    }

    // MARK: - Izgara (Core Graphics)

    public override func draw(_ rect: CGRect) {
        // 4 yatay kesikli çizgi. `gridColor` dinamik UIColor; draw içinde doğru moda çözülür.
        let grid = UIBezierPath()
        let lines = 4
        for index in 0..<lines {
            let y = plotRect.minY + plotRect.height * CGFloat(index) / CGFloat(lines - 1)
            grid.move(to: CGPoint(x: bounds.minX, y: y))
            grid.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        grid.lineWidth = 1 / max(traitCollection.displayScale, 1)
        grid.setLineDash([2, 4], count: 2, phase: 0)
        gridColor.setStroke()
        grid.stroke()
    }

    // MARK: - Çizgi (Core Animation)

    private func updatePaths() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        [lineLayer, fillLayer, fillMask, baselineLayer].forEach { $0.frame = bounds }

        let values = data.values
        guard values.count > 1, plotRect.width > 0 else {
            lineLayer.path = nil
            fillMask.path = nil
            baselineLayer.path = nil
            return
        }

        // Referans çizgisi de görünsün diye ölçeğe dahil ediyoruz.
        let scale = ChartScale(values: values + [data.baseline].compactMap { $0 }, count: values.count, rect: plotRect)

        let line = UIBezierPath()
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: scale.x(at: index), y: scale.y(for: value))
            index == 0 ? line.move(to: point) : line.addLine(to: point)
        }
        lineLayer.path = line.cgPath

        let fill = UIBezierPath(cgPath: line.cgPath)
        fill.addLine(to: CGPoint(x: scale.x(at: values.count - 1), y: bounds.maxY))
        fill.addLine(to: CGPoint(x: scale.x(at: 0), y: bounds.maxY))
        fill.close()
        fillMask.path = fill.cgPath

        if let baseline = data.baseline {
            let y = scale.y(for: baseline)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: bounds.minX, y: y))
            path.addLine(to: CGPoint(x: bounds.maxX, y: y))
            baselineLayer.path = path.cgPath
        } else {
            baselineLayer.path = nil
        }
    }

    private func animateDrawing() {
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 0.6
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        lineLayer.add(draw, forKey: "draw")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.6
        fillLayer.add(fade, forKey: "fade")
    }

    private func updateColors() {
        let resolved = color.resolvedColor(with: traitCollection)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lineLayer.strokeColor = resolved.cgColor
        fillLayer.colors = [resolved.withAlphaComponent(0.25).cgColor, resolved.withAlphaComponent(0).cgColor]
        baselineLayer.strokeColor = gridColor.resolvedColor(with: traitCollection).withAlphaComponent(0.9).cgColor
        CATransaction.commit()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }
}
#endif
