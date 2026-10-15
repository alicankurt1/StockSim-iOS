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

    /// Gerçek BIST kodları, SİMÜLE fiyatlar (gerçek veriyle ilgisi yok).
    public static func bist(seed: UInt64 = 42) -> SimulatorConfiguration {
        SimulatorConfiguration(seed: seed, instruments: [
            SimulatedInstrument("THYAO", name: "Türk Hava Yolları", price: 287.50),
            SimulatedInstrument("ASELS", name: "Aselsan", price: 142.30, volatility: 0.45),
            SimulatedInstrument("GARAN", name: "Garanti BBVA", price: 128.10),
            SimulatedInstrument("AKBNK", name: "Akbank", price: 64.85),
            SimulatedInstrument("BIMAS", name: "BİM Mağazalar", price: 512.00, volatility: 0.25),
            SimulatedInstrument("KCHOL", name: "Koç Holding", price: 198.40, volatility: 0.30),
            SimulatedInstrument("SISE", name: "Şişecam", price: 41.72),
            SimulatedInstrument("EREGL", name: "Ereğli Demir Çelik", price: 26.18),
            SimulatedInstrument("TUPRS", name: "Tüpraş", price: 163.90),
            SimulatedInstrument("FROTO", name: "Ford Otosan", price: 945.00, volatility: 0.30),
        ])
    }
}
