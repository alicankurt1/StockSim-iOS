#if canImport(UIKit)
import UIKit

/// Büyük grafik: ızgara + referans çizgisi + değiştirilebilir çizer + crosshair.
///
/// - Izgara `draw(_:)` ile (Core Graphics): nadiren değişir.
/// - Veri çizimi `renderer`'a ait katmanlarla (Core Animation): sık değişir.
/// - Crosshair: basılı tutup sürükleyince en yakın noktada dikey/yatay çizgi ve nokta.
///   Seçilen indeks `onSelectionChanged` ile dışarı verilir; metni (fiyat, tarih)
///   ekran katmanı kendi formatlar. Bırakınca `nil` gelir.
public final class ChartView: UIView {

    // MARK: Görünüm ayarları

    public var gridColor: UIColor = .separator {
        didSet { setNeedsDisplay(); updateColors() }
    }
    public var upColor: UIColor = .systemGreen {
        didSet { redraw() }
    }
    public var downColor: UIColor = .systemRed {
        didSet { redraw() }
    }
    public var crosshairColor: UIColor = .secondaryLabel {
        didSet { updateColors() }
    }

    /// Çizim tipi. Değiştirmek için yeni bir renderer vermek yeterli (OCP).
    public var renderer: ChartRenderer = LineChartRenderer() {
        didSet {
            oldValue.layers.forEach { $0.removeFromSuperlayer() }
            installRenderer()
            redraw()
            renderer.animateAppearance()
        }
    }

    /// Crosshair'in gösterdiği noktanın indeksi; parmak kalkınca `nil`.
    public var onSelectionChanged: ((Int?) -> Void)?

    // MARK: Durum

    private var data = ChartData(points: [])
    private var lineColor: UIColor = .systemBlue
    private var scale: ChartScale?
    /// Noktaların x konumları: ikili arama için sıralı dizi.
    private var pointXs: [CGFloat] = []
    private var selectedIndex: Int?

    private let rendererContainer = CALayer()
    private let baselineLayer = CAShapeLayer()
    private let crosshairLayer = CAShapeLayer()
    private let crosshairDot = CAShapeLayer()
    private let feedback = UISelectionFeedbackGenerator()

    private var plotRect: CGRect { bounds.insetBy(dx: 4, dy: 6) }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw

        layer.addSublayer(rendererContainer)

        baselineLayer.fillColor = nil
        baselineLayer.lineWidth = 1
        baselineLayer.lineDashPattern = [3, 4]
        layer.addSublayer(baselineLayer)

        crosshairLayer.fillColor = nil
        crosshairLayer.lineWidth = 1
        crosshairLayer.lineDashPattern = [4, 3]
        crosshairLayer.isHidden = true
        layer.addSublayer(crosshairLayer)

        crosshairDot.lineWidth = 2
        crosshairDot.isHidden = true
        layer.addSublayer(crosshairDot)

        installRenderer()
        setUpGesture()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ChartView, _: UITraitCollection) in
                view.redraw()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Veriyi ayarlar. `animated`: aralık değişiminde giriş animasyonu; canlı güncellemede `false`.
    public func setData(_ data: ChartData, lineColor: UIColor, animated: Bool) {
        self.data = data
        self.lineColor = lineColor
        redraw()
        if animated { renderer.animateAppearance() }
        if let selectedIndex { showCrosshair(at: selectedIndex) }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    // MARK: - Izgara (Core Graphics)

    public override func draw(_ rect: CGRect) {
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

    // MARK: - Çizim

    private func installRenderer() {
        renderer.layers.forEach { rendererContainer.addSublayer($0) }
    }

    private func redraw() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        [rendererContainer, baselineLayer, crosshairLayer, crosshairDot].forEach { $0.frame = bounds }

        guard !data.points.isEmpty, plotRect.width > 0 else {
            scale = nil
            pointXs = []
            baselineLayer.path = nil
            renderer.render(data, scale: ChartScale(values: [], count: 0, rect: plotRect), bounds: bounds, palette: palette())
            return
        }

        let scale = ChartScale(values: renderer.scaleValues(for: data), count: data.points.count, rect: plotRect)
        self.scale = scale
        pointXs = data.points.indices.map(scale.x(at:))
        renderer.render(data, scale: scale, bounds: bounds, palette: palette())

        if let baseline = data.baseline {
            let path = CGMutablePath()
            let y = scale.y(for: baseline)
            path.move(to: CGPoint(x: bounds.minX, y: y))
            path.addLine(to: CGPoint(x: bounds.maxX, y: y))
            baselineLayer.path = path
        } else {
            baselineLayer.path = nil
        }
        updateColors()
    }

    private func palette() -> ChartPalette {
        ChartPalette(
            line: lineColor.resolvedColor(with: traitCollection).cgColor,
            up: upColor.resolvedColor(with: traitCollection).cgColor,
            down: downColor.resolvedColor(with: traitCollection).cgColor
        )
    }

    private func updateColors() {
        let crosshair = crosshairColor.resolvedColor(with: traitCollection).cgColor
        crosshairLayer.strokeColor = crosshair
        crosshairDot.strokeColor = crosshair
        crosshairDot.fillColor = backgroundColor?.resolvedColor(with: traitCollection).cgColor
            ?? UIColor.systemBackground.resolvedColor(with: traitCollection).cgColor
        baselineLayer.strokeColor = gridColor.resolvedColor(with: traitCollection).cgColor
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            redraw()
        }
    }

    // MARK: - Crosshair

    private func setUpGesture() {
        // Kısa basılı tutma: dikey kaydırmayla (scroll) çakışmasın diye pan yerine long press.
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        press.minimumPressDuration = 0.15
        addGestureRecognizer(press)
    }

    @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            if gesture.state == .began { feedback.prepare() }
            let x = gesture.location(in: self).x
            guard let index = ChartHitTest.nearestIndex(in: pointXs, to: x) else { return }
            guard index != selectedIndex else { return }
            selectedIndex = index
            showCrosshair(at: index)
            // Her yeni noktada hafif bir "tık" titreşimi.
            feedback.selectionChanged()
            onSelectionChanged?(index)
        default:
            selectedIndex = nil
            crosshairLayer.isHidden = true
            crosshairDot.isHidden = true
            onSelectionChanged?(nil)
        }
    }

    private func showCrosshair(at index: Int) {
        guard let scale, data.points.indices.contains(index) else { return }
        let point = CGPoint(x: scale.x(at: index), y: scale.y(for: data.points[index].close))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let lines = CGMutablePath()
        lines.move(to: CGPoint(x: point.x, y: bounds.minY))
        lines.addLine(to: CGPoint(x: point.x, y: bounds.maxY))
        lines.move(to: CGPoint(x: bounds.minX, y: point.y))
        lines.addLine(to: CGPoint(x: bounds.maxX, y: point.y))
        crosshairLayer.path = lines
        crosshairDot.path = CGPath(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8), transform: nil)
        crosshairLayer.isHidden = false
        crosshairDot.isHidden = false
        CATransaction.commit()
    }
}
#endif
