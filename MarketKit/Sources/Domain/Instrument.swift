/// İşlem görebilen bir hisse: kod + şirket adı. Sadece veri taşır, kural içermez.
public struct Instrument: Hashable, Sendable, Identifiable {

    public let symbol: Symbol
    public let name: String

    /// Diffable data source'ta kimlik olarak hisse kodu kullanılacak.
    public var id: Symbol { symbol }

    public init(symbol: Symbol, name: String) {
        self.symbol = symbol
        self.name = name
    }
}
