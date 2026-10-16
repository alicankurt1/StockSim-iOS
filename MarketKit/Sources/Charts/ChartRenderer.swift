import QuartzCore

/// Çizim renkleri; `ChartView` açık/koyu moda göre çözümleyip verir.
public struct ChartPalette {
    public let line: CGColor
    public let up: CGColor
    public let down: CGColor

    public init(line: CGColor, up: CGColor, down: CGColor) {
        self.line = line
        self.up = up
        self.down = down
    }
}

/// Bir grafik tipinin nasıl çizileceği.
///
/// OCP: `ChartView` sadece bu protokolü bilir. Yeni bir grafik tipi (ör. alan, OHLC çubuk)
/// eklemek için yeni bir renderer yazılır; `ChartView` değişmez.
///
/// Sadece QuartzCore/CoreGraphics kullanır (UIKit değil); macOS'ta da derlenir ve test edilir.
@MainActor
public protocol ChartRenderer: AnyObject {
    /// `ChartView`'ın kendi katmanına ekleyeceği katmanlar (bir kez oluşturulur).
    var layers: [CALayer] { get }
    /// Ölçeğin hangi değerleri kapsaması gerektiği (çizgi: kapanışlar; mum: en yüksek/en düşükler).
    func scaleValues(for data: ChartData) -> [Double]
    func render(_ data: ChartData, scale: ChartScale, bounds: CGRect, palette: ChartPalette)
    /// Veri değişince (aralık/tip değişimi) giriş animasyonu.
    func animateAppearance()
}

// MARK: - Çizgi

@MainActor
public final class LineChartRenderer: ChartRenderer {

    private let lineLayer = CAShapeLayer()
    private let fillLayer = CAGradientLayer()
    private let fillMask = CAShapeLayer()

    public var layers: [CALayer] { [fillLayer, lineLayer] }

    public init() {
        fillLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fillLayer.endPoint = CGPoint(x: 0.5, y: 1)
        fillLayer.mask = fillMask

        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round
    }

    public func scaleValues(for data: ChartData) -> [Double] {
        data.points.map(\.close) + [data.baseline].compactMap { $0 }
    }

    public func render(_ data: ChartData, scale: ChartScale, bounds: CGRect, palette: ChartPalette) {
        [lineLayer, fillLayer, fillMask].forEach { $0.frame = bounds }
        lineLayer.strokeColor = palette.line
        fillLayer.colors = [palette.line.copy(alpha: 0.25)!, palette.line.copy(alpha: 0)!]

        guard data.points.count > 1 else {
            lineLayer.path = nil
            fillMask.path = nil
            return
        }

        let line = CGMutablePath()
        for (index, point) in data.points.enumerated() {
            let position = CGPoint(x: scale.x(at: index), y: scale.y(for: point.close))
            index == 0 ? line.move(to: position) : line.addLine(to: position)
        }
        lineLayer.path = line

        let fill = line.mutableCopy()!
        fill.addLine(to: CGPoint(x: scale.x(at: data.points.count - 1), y: bounds.maxY))
        fill.addLine(to: CGPoint(x: scale.x(at: 0), y: bounds.maxY))
        fill.closeSubpath()
        fillMask.path = fill
    }

    public func animateAppearance() {
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 0.6
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        lineLayer.add(draw, forKey: "draw")
        fillLayer.add(fade(duration: 0.6), forKey: "fade")
    }
}

// MARK: - Mum

/// Her mum: ince bir fitil (en yüksek–en düşük) + kalın bir gövde (açılış–kapanış).
/// Yükselenler ve düşenler ayrı katmanlarda: binlerce küçük katman yerine 4 katman, 4 path.
@MainActor
public final class CandlestickChartRenderer: ChartRenderer {

    private let risingBodies = CAShapeLayer()
    private let fallingBodies = CAShapeLayer()
    private let risingWicks = CAShapeLayer()
    private let fallingWicks = CAShapeLayer()

    public var layers: [CALayer] { [risingWicks, fallingWicks, risingBodies, fallingBodies] }

    public init() {
        [risingWicks, fallingWicks].forEach {
            $0.fillColor = nil
            $0.lineWidth = 1
        }
        [risingBodies, fallingBodies].forEach { $0.lineWidth = 0 }
    }

    public func scaleValues(for data: ChartData) -> [Double] {
        data.points.flatMap { [$0.high, $0.low] } + [data.baseline].compactMap { $0 }
    }

    public func render(_ data: ChartData, scale: ChartScale, bounds: CGRect, palette: ChartPalette) {
        layers.forEach { $0.frame = bounds }
        risingBodies.fillColor = palette.up
        risingWicks.strokeColor = palette.up
        fallingBodies.fillColor = palette.down
        fallingWicks.strokeColor = palette.down

        let width = CandleGeometry.bodyWidth(step: scale.count > 1 ? scale.step : bounds.width)
        let paths = (risingBodies: CGMutablePath(), fallingBodies: CGMutablePath(),
                     risingWicks: CGMutablePath(), fallingWicks: CGMutablePath())

        for (index, point) in data.points.enumerated() {
            let x = scale.x(at: index)
            let wick = CandleGeometry.wick(high: point.high, low: point.low, x: x, scale: scale)
            let body = CandleGeometry.bodyRect(open: point.open, close: point.close, x: x, width: width, scale: scale)
            let wickPath = point.isRising ? paths.risingWicks : paths.fallingWicks
            wickPath.move(to: wick.top)
            wickPath.addLine(to: wick.bottom)
            (point.isRising ? paths.risingBodies : paths.fallingBodies).addRect(body)
        }

        risingBodies.path = paths.risingBodies
        fallingBodies.path = paths.fallingBodies
        risingWicks.path = paths.risingWicks
        fallingWicks.path = paths.fallingWicks
    }

    public func animateAppearance() {
        layers.forEach { $0.add(fade(duration: 0.4), forKey: "fade") }
    }
}

private func fade(duration: CFTimeInterval) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = 0
    animation.toValue = 1
    animation.duration = duration
    return animation
}
