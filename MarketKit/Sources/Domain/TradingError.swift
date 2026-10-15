/// Al/sat kurallarının ihlali. Interactor bunları kullanıcıya gösterilecek mesaja çevirecek.
public enum TradingError: Error, Equatable, Sendable {
    /// Adet sıfır ya da negatif.
    case invalidQuantity
    /// Elde olandan fazla satılmak istendi.
    case insufficientQuantity(available: Int, requested: Int)
    /// Alım tutarı nakitten fazla.
    case insufficientCash(available: Money, required: Money)
    /// Emir tipi şu anki fiyattan gerçekleşemiyor (ör. limit fiyata ulaşılmadı).
    case orderNotFillable
    /// Hissede işlem durduruldu (simülatörün `halt` tetikleyicisi). Phase 7'de kullanılacak.
    case marketHalted(Symbol)
}
