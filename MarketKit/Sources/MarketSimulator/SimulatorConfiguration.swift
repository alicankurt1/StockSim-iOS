import Foundation
import Domain

/// Simüle edilen bir hisse ve fiyat davranışı.
public struct SimulatedInstrument: Sendable {
    public let instrument: Instrument
    /// Önceki kapanış; simülasyon buradan başlar.
    public let initialPrice: Double
    /// μ: yıllık beklenen getiri.
    public let drift: Double
    /// σ: yıllık oynaklık.
    public let volatility: Double

    public init(_ symbol: String, name: String, price: Double, drift: Double = 0.05, volatility: Double = 0.35) {
        self.instrument = Instrument(symbol: Symbol(symbol), name: name)
        self.initialPrice = price
        self.drift = drift
        self.volatility = volatility
    }
}

public struct SimulatorConfiguration: Sendable {
    /// Aynı seed → aynı fiyat yolu.
    public var seed: UInt64
    public var instruments: [SimulatedInstrument]
    /// Gerçek zamanda iki tick arasındaki süre.
    public var tickInterval: Duration
    /// Her tick piyasada kaç yıllık zamana denk geliyor. Varsayılan: 1 işlem dakikası
    /// (252 gün × 8 saat × 60 dk). Saniyede bir tick ile hareket gözle görülür olur.
    public var yearsPerTick: Double
    /// Aramada bulunabilen ve izleme listesine eklenince fiyatlanan hisseler.
    public var directory: [Instrument]

    public init(
        seed: UInt64,
        instruments: [SimulatedInstrument],
        tickInterval: Duration = .seconds(1),
        yearsPerTick: Double = 1.0 / (252 * 8 * 60),
        directory: [Instrument] = []
    ) {
        self.seed = seed
        self.instruments = instruments
        self.tickInterval = tickInterval
        self.yearsPerTick = yearsPerTick
        self.directory = directory
    }

    /// Yük testi: çok sayıda uydurma hisse, sık tick (varsayılan 120 hisse × 10/sn = 1.200 güncelleme/sn).
    public static func stress(count: Int = 120, tickInterval: Duration = .milliseconds(100), seed: UInt64 = 7) -> SimulatorConfiguration {
        let instruments = (1...count).map { index in
            let code = String(format: "STR%03d", index)
            let price = 20 + Double(stableHash(code) % 48_000) / 100
            return SimulatedInstrument(code, name: "Stress test \(index)", price: price, volatility: 0.6)
        }
        return SimulatorConfiguration(seed: seed, instruments: instruments, tickInterval: tickInterval)
    }

    /// Gerçek BIST kodları (`BistCatalog`), SİMÜLE fiyatlar (gerçek veriyle ilgisi yok).
    public static func bist(seed: UInt64 = 42) -> SimulatorConfiguration {
        universe(.bist, seed: seed)
    }

    /// Uydurma şirketler (dağıtım derlemesi). Fiyat davranışı BIST listesiyle aynı sırada.
    public static func fictional(seed: UInt64 = 42) -> SimulatorConfiguration {
        universe(.fictional, seed: seed)
    }

    /// Öne çıkan hisseler sırayla bu başlangıç fiyatı ve oynaklıkları alır; fazlası varsayılanla başlar.
    private static let behaviour: [(price: Double, volatility: Double)] = [
        (287.50, 0.35), (142.30, 0.45), (128.10, 0.35), (64.85, 0.35), (512.00, 0.25),
        (198.40, 0.30), (41.72, 0.35), (26.18, 0.35), (163.90, 0.35), (945.00, 0.30),
    ]

    private static func universe(_ universe: MarketUniverse, seed: UInt64) -> SimulatorConfiguration {
        let instruments = universe.featured.enumerated().map { index, instrument in
            let values = index < behaviour.count ? behaviour[index] : (price: 100, volatility: 0.35)
            return SimulatedInstrument(
                instrument.symbol.rawValue, name: instrument.name, price: values.price, volatility: values.volatility
            )
        }
        return SimulatorConfiguration(seed: seed, instruments: instruments, directory: universe.directory)
    }
}
