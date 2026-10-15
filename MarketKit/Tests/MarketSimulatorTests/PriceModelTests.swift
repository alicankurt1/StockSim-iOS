import Foundation
import Testing
import Domain
@testable import MarketSimulator

struct SeededGeneratorTests {

    @Test func sameSeedProducesSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
    }

    @Test func differentSeedsProduceDifferentSequences() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        #expect(a.next() != b.next())
    }

    /// SplitMix64'ün bilinen ilk çıktısı: algoritmayı doğru yazdığımızın kanıtı.
    @Test func matchesReferenceSplitMix64() {
        var generator = SeededGenerator(seed: 0)
        #expect(generator.next() == 0xE220_A839_7B1D_CDAF)
    }

    /// Box–Muller çıktısı ortalaması ~0, standart sapması ~1 olmalı.
    @Test func gaussianHasZeroMeanAndUnitDeviation() {
        var generator = SeededGenerator(seed: 7)
        let samples = (0..<20_000).map { _ in generator.nextGaussian() }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count)
        #expect(abs(mean) < 0.05)
        #expect(abs(variance.squareRoot() - 1) < 0.05)
    }

    /// `hashValue`'nun aksine her çalıştırmada aynı (FNV-1a referans değerleri).
    @Test func stableHashIsStable() {
        #expect(stableHash("") == 0xCBF2_9CE4_8422_2325)
        #expect(stableHash("a") == 0xAF63_DC4C_8601_EC8C)
    }
}

struct PriceModelTests {

    @Test func noDriftNoVolatilityKeepsPrice() {
        #expect(PriceModel.nextPrice(100, drift: 0, volatility: 0, dt: 0.01, z: 1.5) == 100)
    }

    @Test(arguments: [-3.0, 0.0, 3.0])
    func positiveShockRaisesNegativeLowers(z: Double) {
        let next = PriceModel.nextPrice(100, drift: 0, volatility: 0.4, dt: 0.01, z: z)
        if z > 0 { #expect(next > 100) }
        if z < 0 { #expect(next < 100) }
        #expect(next > 0)
    }

    /// Geriye yürümek, ileri adımı tam olarak geri alır.
    @Test func previousPriceUndoesNextPrice() {
        let next = PriceModel.nextPrice(287.5, drift: 0.05, volatility: 0.35, dt: 0.001, z: 0.8)
        let back = PriceModel.previousPrice(next, drift: 0.05, volatility: 0.35, dt: 0.001, z: 0.8)
        #expect(abs(back - 287.5) < 1e-9)
    }

    /// Fiyat kuruşa yuvarlanır.
    @Test(arguments: [
        (287.499, "287.5"),
        (287.505, "287.51"),
        (0.004, "0"),
        (1000.0, "1000"),
    ])
    func moneyRoundsToCents(price: Double, expected: String) {
        #expect(PriceModel.money(price) == Money(Decimal(string: expected)!))
    }
}

struct HistoryGeneratorTests {

    private let end = Date(timeIntervalSince1970: 1_800_000_000)

    private func candles(_ range: ChartRange, seed: UInt64 = 1) -> [Candle] {
        HistoryGenerator.candles(endingAt: 287.5, end: end, range: range, drift: 0.05, volatility: 0.35, seed: seed)
    }

    @Test(arguments: [(ChartRange.day, 96), (.week, 40), (.month, 22), (.year, 52)])
    func candleCountPerRange(range: ChartRange, count: Int) {
        #expect(candles(range).count == count)
    }

    @Test(arguments: ChartRange.allCases)
    func lastCandleClosesAtCurrentPrice(range: ChartRange) {
        #expect(candles(range).last?.close == PriceModel.money(287.5))
    }

    @Test(arguments: ChartRange.allCases)
    func candlesAreValidAndChained(range: ChartRange) {
        let candles = candles(range)
        for candle in candles {
            #expect(candle.high >= max(candle.open, candle.close))
            #expect(candle.low <= min(candle.open, candle.close))
        }
        // Tarihler artan sırada ve hepsi bitişten önce; her mum bir öncekinin kapanışından açılır.
        for (previous, current) in zip(candles, candles.dropFirst()) {
            #expect(previous.date < current.date)
            #expect(previous.close == current.open)
        }
        #expect(candles.last!.date < end)
    }

    @Test func sameSeedSameHistory() {
        #expect(candles(.month, seed: 5) == candles(.month, seed: 5))
        #expect(candles(.month, seed: 5) != candles(.month, seed: 6))
    }
}
