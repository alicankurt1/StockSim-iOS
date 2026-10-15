import Foundation
import Domain

/// Bir hisse için geçmiş mumları üretir.
///
/// Güncel fiyattan GERİYE doğru yürür; böylece grafiğin son mumu her zaman
/// ekrandaki canlı fiyatla biter. Aynı seed → aynı geçmiş.
enum HistoryGenerator {

    /// Her aralığın mum sayısı, mum süresi (tarih için) ve piyasa zamanı (yıl cinsinden).
    struct Spec {
        let count: Int
        let candleInterval: TimeInterval
        let yearsPerCandle: Double
    }

    /// Bir mumun içindeki ara adım sayısı (açılış, en yüksek, en düşük bunlardan çıkar).
    static let stepsPerCandle = 4

    static func spec(for range: ChartRange) -> Spec {
        let tradingMinutesPerYear = 252.0 * 8 * 60
        switch range {
        case .day:   return Spec(count: 96, candleInterval: 5 * 60, yearsPerCandle: 5 / tradingMinutesPerYear)
        case .week:  return Spec(count: 40, candleInterval: 60 * 60, yearsPerCandle: 60 / tradingMinutesPerYear)
        case .month: return Spec(count: 22, candleInterval: 24 * 60 * 60, yearsPerCandle: 1 / 252)
        case .year:  return Spec(count: 52, candleInterval: 7 * 24 * 60 * 60, yearsPerCandle: 5 / 252)
        }
    }

    static func candles(
        endingAt endPrice: Double,
        end: Date,
        range: ChartRange,
        drift: Double,
        volatility: Double,
        seed: UInt64
    ) -> [Candle] {
        let spec = spec(for: range)
        let dt = spec.yearsPerCandle / Double(stepsPerCandle)
        var generator = SeededGenerator(seed: seed)
        var candles: [Candle] = []
        var close = endPrice

        // Sondan başa: her mumun kapanışı bir sonrakinin açılışıdır.
        for index in stride(from: spec.count - 1, through: 0, by: -1) {
            var points = [close]
            for _ in 0..<stepsPerCandle {
                let earlier = PriceModel.previousPrice(
                    points[points.count - 1], drift: drift, volatility: volatility, dt: dt, z: generator.nextGaussian()
                )
                points.append(earlier)
            }
            let open = points[points.count - 1]
            candles.append(Candle(
                date: end.addingTimeInterval(-spec.candleInterval * Double(spec.count - index)),
                open: PriceModel.money(open),
                high: PriceModel.money(points.max()!),
                low: PriceModel.money(points.min()!),
                close: PriceModel.money(close)
            ))
            close = open
        }
        return candles.reversed()
    }
}
