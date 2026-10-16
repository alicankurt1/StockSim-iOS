import Foundation

// Piyasa verisi sözleşmesi. Ekranlar sadece bu protokolleri bilir; arkasında
// simülatör mü (Phase 2) gerçek veri mi (Phase 9) olduğunu AppAssembler seçer.

/// Grafik aralığı: 1G / 1H / 1A / 1Y.
public enum ChartRange: String, CaseIterable, Sendable {
    case day, week, month, year
}

/// Fiyat akışından gelen olaylar.
public enum MarketUpdate: Sendable, Equatable {
    /// Yeni fiyat.
    case quote(Quote)
    /// Hissede işlem durduruldu; fiyat gelmez, al/sat reddedilir.
    case halted(Symbol)
    case resumed(Symbol)
    /// Akış koptu: ekrandaki fiyatlar eskidi.
    case feedInterrupted
    case feedRestored
}

public enum MarketDataError: Error, Equatable, Sendable {
    case unknownSymbol(Symbol)
}

/// Fiyat kaynağı (LSP: simülatör, gerçek veri ve test sahtesi birbirinin yerine geçebilir).
public protocol MarketDataProviding: Sendable {
    func instruments() async throws -> [Instrument]
    /// Verilen hisselerin anlık fiyatları (tek seferlik). Bilinmeyen hisseler atlanır.
    func quotes(for symbols: [Symbol]) async throws -> [Quote]
    /// Verilen hisselerin canlı akışı. Abone olunca önce güncel fiyatlar gelir.
    func updates(for symbols: [Symbol]) async -> AsyncStream<MarketUpdate>
    func history(for symbol: Symbol, range: ChartRange) async throws -> [Candle]
}

/// Uç durum tetikleyicileri. Sadece simülatör uygular.
public enum MarketEvent: Sendable, Equatable {
    /// Ani düşüş; `symbol` nil ise tüm hisseler.
    case crash(Symbol?, percent: Decimal)
    /// Volatilite bir süreliğine katlanır.
    case volatilitySpike(multiplier: Double, duration: Duration)
    case halt(Symbol)
    case resume(Symbol)
    /// Akış bir süre susar, sonra geri gelir.
    case dropFeed(duration: Duration)
}

/// ISP: fiyat okumak isteyen ekranlar bu protokolü görmez; sadece debug menüsü kullanır.
public protocol MarketControlling: Sendable {
    func trigger(_ event: MarketEvent) async
}
