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

    public init(
        seed: UInt64,
        instruments: [SimulatedInstrument],
        tickInterval: Duration = .seconds(1),
        yearsPerTick: Double = 1.0 / (252 * 8 * 60)
    ) {
        self.seed = seed
        self.instruments = instruments
        self.tickInterval = tickInterval
        self.yearsPerTick = yearsPerTick
    }

    /// Gerçek BIST kodları (`BistCatalog`), SİMÜLE fiyatlar (gerçek veriyle ilgisi yok).
    public static func bist(seed: UInt64 = 42) -> SimulatorConfiguration {
        // Başlangıç fiyatı ve oynaklık; hisse listesi ve isimler katalogdan.
        let behaviour: [String: (price: Double, volatility: Double)] = [
            "THYAO": (287.50, 0.35), "ASELS": (142.30, 0.45), "GARAN": (128.10, 0.35),
            "AKBNK": (64.85, 0.35), "BIMAS": (512.00, 0.25), "KCHOL": (198.40, 0.30),
            "SISE": (41.72, 0.35), "EREGL": (26.18, 0.35), "TUPRS": (163.90, 0.35),
            "FROTO": (945.00, 0.30),
        ]
        return SimulatorConfiguration(seed: seed, instruments: BistCatalog.instruments.map { instrument in
            let values = behaviour[instrument.symbol.rawValue] ?? (100, 0.35)
            return SimulatedInstrument(
                instrument.symbol.rawValue, name: instrument.name, price: values.price, volatility: values.volatility
            )
        })
    }
}
