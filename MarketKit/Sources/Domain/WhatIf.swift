import Foundation

/// "Şu tarihte şu hisseye şu kadar para yatırsaydım?" senaryosu.
///
/// Gerçek portföyden farklı olarak kesirli adet olabilir (100.000 ₺ / 287,50 ₺ = 347,83 adet):
/// amaç "o para bugün ne olurdu" sorusunu cevaplamak, emir kurallarını değil.
public struct WhatIfScenario: Identifiable, Hashable, Sendable {

    public let id: UUID
    public let instrument: Instrument
    public let amount: Money
    /// Kullanıcının seçtiği tarih.
    public let startDate: Date
    /// O tarihteki (ya da sonraki ilk işlem günündeki) alım fiyatı.
    public let entryPrice: Money

    public init(id: UUID = UUID(), instrument: Instrument, amount: Money, startDate: Date, entryPrice: Money) {
        self.id = id
        self.instrument = instrument
        self.amount = amount
        self.startDate = startDate
        self.entryPrice = entryPrice
    }

    /// Alınacak adet (kesirli).
    public var shares: Decimal {
        entryPrice.amount > 0 ? amount.amount / entryPrice.amount : 0
    }

    public func value(at price: Money) -> Money {
        Money(shares * price.amount)
    }

    public func profitLoss(at price: Money) -> Money {
        value(at: price) - amount
    }

    /// Yüzde getiri; adet hesabına bağlı değil, sadece fiyat oranı.
    public func returnPercent(at price: Money) -> Decimal {
        entryPrice.amount > 0 ? (price.amount - entryPrice.amount) / entryPrice.amount * 100 : 0
    }
}

/// Senaryo hesaplarının saf yardımcıları (macOS'ta test edilir).
public enum WhatIfCalculator {

    /// Seçilen tarihe göre hangi geçmiş aralığı gerekli: son 1 ay günlük, daha eskisi haftalık.
    public static func range(for date: Date, now: Date) -> ChartRange {
        now.timeIntervalSince(date) <= 31 * 24 * 60 * 60 ? .month : .year
    }

    /// Alım mumu: seçilen günden itibaren ilk mum (hafta sonu/tatil seçildiyse sonraki işlem günü).
    /// Seçilen tarih son mumdan da sonraysa (ör. bugün) son mum.
    public static func entryIndex(in candles: [Candle], on date: Date, calendar: Calendar = .current) -> Int? {
        guard !candles.isEmpty else { return nil }
        let startOfDay = calendar.startOfDay(for: date)
        return candles.firstIndex { $0.date >= startOfDay } ?? candles.count - 1
    }
}

/// Senaryoların saklandığı yer (portföy ve izleme listesi depolarıyla aynı desen).
public protocol WhatIfRepository: Sendable {
    func load() throws -> [WhatIfScenario]?
    func save(_ scenarios: [WhatIfScenario]) throws
}

public protocol WhatIfStoring: Sendable {
    func current() async -> [WhatIfScenario]
    func add(_ scenario: WhatIfScenario) async
    /// Aynı `id`'li senaryoyu yerinde değiştirir (listedeki sırası korunur).
    func update(_ scenario: WhatIfScenario) async
    func remove(_ id: UUID) async
    func changes() async -> AsyncStream<[WhatIfScenario]>
}

/// Takip edilen senaryolar. Oluşturucu ve liste ekranı aynı anda kullanır → actor.
public actor WhatIfStore: WhatIfStoring {

    private var scenarios: [WhatIfScenario]
    private let repository: WhatIfRepository?
    private var observers: [UUID: AsyncStream<[WhatIfScenario]>.Continuation] = [:]

    public init(repository: WhatIfRepository? = nil) {
        self.repository = repository
        self.scenarios = ((try? repository?.load()) ?? nil) ?? []
    }

    public func current() -> [WhatIfScenario] {
        scenarios
    }

    /// En yeni üstte.
    public func add(_ scenario: WhatIfScenario) {
        scenarios.insert(scenario, at: 0)
        didChange()
    }

    public func update(_ scenario: WhatIfScenario) {
        guard let index = scenarios.firstIndex(where: { $0.id == scenario.id }) else { return }
        scenarios[index] = scenario
        didChange()
    }

    public func remove(_ id: UUID) {
        scenarios.removeAll { $0.id == id }
        didChange()
    }

    public func changes() -> AsyncStream<[WhatIfScenario]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [WhatIfScenario].self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        continuation.yield(scenarios)
        return stream
    }

    private func didChange() {
        try? repository?.save(scenarios)
        observers.values.forEach { $0.yield(scenarios) }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
