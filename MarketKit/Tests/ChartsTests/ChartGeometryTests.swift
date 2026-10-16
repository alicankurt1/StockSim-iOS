import CoreGraphics
import Testing
@testable import Charts

struct ChartHitTestTests {

    private let xs: [CGFloat] = [0, 10, 20, 30, 40]

    /// İkili arama: en yakın nokta; eşit uzaklıkta soldaki seçilir; dışarı taşanlar kenara.
    @Test(arguments: [
        (CGFloat(0), 0), (4, 0), (5, 0), (6, 1), (19, 2), (21, 2), (34, 3), (36, 4), (-50, 0), (500, 4),
    ])
    func nearestIndex(x: CGFloat, expected: Int) {
        #expect(ChartHitTest.nearestIndex(in: xs, to: x) == expected)
    }

    @Test func emptyHasNoIndex() {
        #expect(ChartHitTest.nearestIndex(in: [], to: 10) == nil)
    }

    @Test func singlePointAlwaysWins() {
        #expect(ChartHitTest.nearestIndex(in: [50], to: -100) == 0)
    }

    /// Büyük dizide de doğrusal aramayla aynı sonucu verir.
    @Test func matchesLinearSearchOnLargeInput() {
        let large = (0..<1000).map { CGFloat($0) * 1.7 }
        for x in stride(from: CGFloat(-5), through: 1720, by: 13.3) {
            let linear = large.indices.min { abs(large[$0] - x) < abs(large[$1] - x) }
            #expect(ChartHitTest.nearestIndex(in: large, to: x) == linear)
        }
    }
}

struct CandleGeometryTests {

    private let scale = ChartScale(values: [0, 100], count: 2, rect: CGRect(x: 0, y: 0, width: 100, height: 100), padding: 0)

    @Test(arguments: [(CGFloat(2), CGFloat(1.2)), (10, 6), (100, 14), (0.5, 1)])
    func bodyWidthIsClamped(step: CGFloat, expected: CGFloat) {
        #expect(abs(CandleGeometry.bodyWidth(step: step) - expected) < 1e-9)
    }

    /// Gövde açılış–kapanış arasında; yükselen ya da düşen olması fark etmez.
    @Test(arguments: [(40.0, 60.0), (60.0, 40.0)])
    func bodySpansOpenAndClose(open: Double, close: Double) {
        let body = CandleGeometry.bodyRect(open: open, close: close, x: 50, width: 10, scale: scale)
        #expect(body == CGRect(x: 45, y: 40, width: 10, height: 20))
    }

    @Test func flatCandleHasMinimumHeight() {
        #expect(CandleGeometry.bodyRect(open: 50, close: 50, x: 50, width: 10, scale: scale).height == 1)
    }

    @Test func wickSpansHighToLow() {
        let wick = CandleGeometry.wick(high: 90, low: 10, x: 30, scale: scale)
        #expect(wick.top == CGPoint(x: 30, y: 10))
        #expect(wick.bottom == CGPoint(x: 30, y: 90))
    }
}

@MainActor
struct ChartRendererTests {

    private let data = ChartData(
        points: [ChartPoint(open: 10, high: 15, low: 8, close: 12), ChartPoint(open: 12, high: 20, low: 11, close: 18)],
        baseline: 9
    )

    /// Çizgi sadece kapanışları ölçer; mum, fitillerin uçlarını da kapsamalı.
    @Test func lineScalesClosesAndBaseline() {
        #expect(LineChartRenderer().scaleValues(for: data) == [12, 18, 9])
    }

    @Test func candlesScaleHighsLowsAndBaseline() {
        #expect(CandlestickChartRenderer().scaleValues(for: data) == [15, 8, 20, 11, 9])
    }
}
