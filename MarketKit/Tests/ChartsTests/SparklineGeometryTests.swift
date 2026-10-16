import CoreGraphics
import Testing
@testable import Charts

/// Çizimin matematiği UI olmadan, macOS'ta test ediliyor.
struct SparklineGeometryTests {

    private let size = CGSize(width: 100, height: 50)

    @Test func emptyValuesProduceNoPoints() {
        #expect(SparklineGeometry.points(for: [], in: size).isEmpty)
    }

    @Test func zeroSizeProducesNoPoints() {
        #expect(SparklineGeometry.points(for: [1, 2], in: .zero).isEmpty)
    }

    @Test func pointsSpanTheWidthEvenly() {
        let points = SparklineGeometry.points(for: [1, 2, 3, 4, 5], in: size, inset: 0)
        #expect(points.map(\.x) == [0, 25, 50, 75, 100])
    }

    /// UIKit'te y aşağı doğru artar: en büyük değer en üstte (y = 0), en küçük en altta.
    @Test func highestValueIsAtTopLowestAtBottom() {
        let points = SparklineGeometry.points(for: [10, 30, 20], in: size, inset: 0)
        #expect(points.map(\.y) == [50, 0, 25])
    }

    @Test func insetKeepsPointsInsideTheEdges() {
        let points = SparklineGeometry.points(for: [10, 30], in: size, inset: 2)
        #expect(points.first == CGPoint(x: 2, y: 48))
        #expect(points.last == CGPoint(x: 98, y: 2))
    }

    @Test(arguments: [[5.0, 5.0, 5.0], [7.0]])
    func flatOrSingleValueIsCenteredVertically(values: [Double]) {
        let points = SparklineGeometry.points(for: values, in: size, inset: 0)
        #expect(points.allSatisfy { $0.y == 25 })
    }

    @Test func singleValueIsCenteredHorizontally() {
        #expect(SparklineGeometry.points(for: [7], in: size, inset: 0).first?.x == 50)
    }
}
