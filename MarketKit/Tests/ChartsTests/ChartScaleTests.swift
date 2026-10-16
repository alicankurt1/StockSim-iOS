import CoreGraphics
import Testing
@testable import Charts

struct ChartScaleTests {

    private let rect = CGRect(x: 0, y: 0, width: 300, height: 100)

    private func scale(_ values: [Double], padding: Double = 0) -> ChartScale {
        ChartScale(values: values, count: values.count, rect: rect, padding: padding)
    }

    @Test func xSpreadsIndicesEvenly() {
        let scale = scale([1, 2, 3, 4])
        #expect((0..<4).map(scale.x(at:)) == [0, 100, 200, 300])
    }

    @Test func singlePointSitsInTheMiddle() {
        #expect(scale([5]).x(at: 0) == 150)
    }

    /// Padding olmadan: en büyük değer en üstte, en küçük en altta.
    @Test func yMapsMaxToTopAndMinToBottom() {
        let scale = scale([10, 20])
        #expect(scale.y(for: 20) == 0)
        #expect(scale.y(for: 10) == 100)
        #expect(scale.y(for: 15) == 50)
    }

    /// %10 padding: aralık her iki yönde %10 genişler; uç noktalar kenara yapışmaz.
    @Test func paddingWidensTheRange() {
        let scale = scale([10, 20], padding: 0.1)
        #expect(scale.minValue == 9)
        #expect(scale.maxValue == 21)
        #expect(scale.y(for: 20) > 0)
        #expect(scale.y(for: 10) < 100)
    }

    @Test func flatSeriesDoesNotDivideByZero() {
        let scale = scale([50, 50, 50])
        #expect(scale.maxValue > scale.minValue)
        #expect(scale.y(for: 50) == 50)
    }

    @Test(arguments: [0.0, 37.5, 61.2, 99.0])
    func valueAtYIsTheInverseOfY(value: Double) {
        let scale = scale([0, 100], padding: 0.08)
        #expect(abs(scale.value(atY: scale.y(for: value)) - value) < 1e-9)
    }

    /// Dokunulan x'e en yakın nokta; dışarı taşan dokunuşlar kenara sabitlenir.
    @Test(arguments: [
        (CGFloat(0), 0), (49, 0), (51, 1), (140, 1), (160, 2), (300, 3), (-40, 0), (900, 3),
    ])
    func nearestIndex(x: CGFloat, expected: Int) {
        #expect(scale([1, 2, 3, 4]).index(nearestTo: x) == expected)
    }
}
