import Foundation
import Domain

/// Uygulamanın içindeki sahte borsa.
///
/// Neden `actor`? Fiyatlar, aboneler ve tetikleyici durumları birden fazla yerden
/// (fiyat döngüsü, ekranlar, debug menüsü) aynı anda okunup değiştiriliyor.
/// Actor bu erişimleri sıraya koyar; veri yarışı (data race) olmaz.
public actor MarketSimulator: MarketDataProviding, MarketControlling {

    private struct Subscriber {
        let symbols: Set<Symbol>
        let continuation: AsyncStream<MarketUpdate>.Continuation

        /// Akış olayları herkese, hisse olayları sadece o hisseyi isteyene.
        func wants(_ update: MarketUpdate) -> Bool {
            switch update {
            case let .quote(quote): symbols.contains(quote.symbol)
            case let .halted(symbol), let .resumed(symbol): symbols.contains(symbol)
            case .feedInterrupted, .feedRestored: true
            }
        }
    }

    private let configuration: SimulatorConfiguration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: @Sendable () -> Date

    private var generator: SeededGenerator
    private var prices: [Symbol: Double]
    private let previousCloses: [Symbol: Money]
    private var halted: Set<Symbol> = []
    private var volatilityMultiplier = 1.0
    private var spikeTicksRemaining = 0
    private var feedDropTicksRemaining = 0
    private var subscribers: [UUID: Subscriber] = [:]
    private var loop: Task<Void, Never>?

    /// - Parameters:
    ///   - sleep: iki tick arası bekleme. Testlerde beklemeden geçen bir closure verilir (DI).
    ///   - now: saat. Testlerde sabit bir tarih verilir.
    public init(
        configuration: SimulatorConfiguration = .bist(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.sleep = sleep
        self.now = now
        self.generator = SeededGenerator(seed: configuration.seed)

        var prices: [Symbol: Double] = [:]
        var previousCloses: [Symbol: Money] = [:]
        for item in configuration.instruments {
            prices[item.instrument.symbol] = item.initialPrice
            previousCloses[item.instrument.symbol] = PriceModel.money(item.initialPrice)
        }
        self.prices = prices
        self.previousCloses = previousCloses
    }

    // MARK: - Döngü

    /// Fiyat döngüsünü başlatır: her `tickInterval`'da bir tick.
    public func start() {
        guard loop == nil else { return }
        let interval = configuration.tickInterval
        loop = Task { [weak self, sleep] in
            while !Task.isCancelled {
                do { try await sleep(interval) } catch { return }
                await self?.tick()
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    /// Tüm hisseleri bir adım ilerletir ve abonelere yollar.
    /// Testler döngüyü beklemek yerine bunu doğrudan çağırır.
    func tick() {
        let dt = configuration.yearsPerTick
        for item in configuration.instruments {
            let symbol = item.instrument.symbol
            // Rastgele sayı her hisse için HER ZAMAN çekilir; böylece bir hissenin durdurulması
            // diğerlerinin fiyat yolunu değiştirmez (determinizm).
            let z = generator.nextGaussian()
            guard !halted.contains(symbol), let price = prices[symbol] else { continue }
            prices[symbol] = PriceModel.nextPrice(
                price, drift: item.drift, volatility: item.volatility * volatilityMultiplier, dt: dt, z: z
            )
        }

        if spikeTicksRemaining > 0 {
            spikeTicksRemaining -= 1
            if spikeTicksRemaining == 0 { volatilityMultiplier = 1 }
        }

        if feedDropTicksRemaining > 0 {
            feedDropTicksRemaining -= 1
            guard feedDropTicksRemaining == 0 else { return }
            broadcast(.feedRestored, force: true)
        }
        broadcastAllQuotes()
    }

    // MARK: - MarketDataProviding

    public func instruments() -> [Instrument] {
        configuration.instruments.map(\.instrument)
    }

    public func quotes(for symbols: [Symbol]) -> [Quote] {
        symbols.compactMap { quote(for: $0) }
    }

    public func updates(for symbols: [Symbol]) -> AsyncStream<MarketUpdate> {
        let (stream, continuation) = AsyncStream.makeStream(of: MarketUpdate.self, bufferingPolicy: .bufferingNewest(256))
        let id = UUID()
        let subscriber = Subscriber(symbols: Set(symbols), continuation: continuation)
        subscribers[id] = subscriber

        // Akışı dinleyen taraf bırakınca (ekran kapanınca) aboneyi sil.
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }

        // İlk değerler: ekran boş başlamasın.
        if feedDropTicksRemaining > 0 {
            continuation.yield(.feedInterrupted)
        }
        for symbol in symbols {
            if let quote = quote(for: symbol) { continuation.yield(.quote(quote)) }
            if halted.contains(symbol) { continuation.yield(.halted(symbol)) }
        }
        return stream
    }

    public func history(for symbol: Symbol, range: ChartRange) throws -> [Candle] {
        guard let item = configuration.instruments.first(where: { $0.instrument.symbol == symbol }),
              let price = prices[symbol] else {
            throw MarketDataError.unknownSymbol(symbol)
        }
        let rangeIndex = UInt64(ChartRange.allCases.firstIndex(of: range)!)
        return HistoryGenerator.candles(
            endingAt: price,
            end: now(),
            range: range,
            drift: item.drift,
            volatility: item.volatility,
            seed: configuration.seed ^ stableHash(symbol.rawValue) ^ (rangeIndex &* 0x9E37_79B9)
        )
    }

    /// Hissenin anlık fiyatı (al/sat ekranı için).
    public func quote(for symbol: Symbol) -> Quote? {
        guard let price = prices[symbol], let previousClose = previousCloses[symbol] else { return nil }
        return Quote(symbol: symbol, price: PriceModel.money(price), previousClose: previousClose, timestamp: now())
    }

    public func isHalted(_ symbol: Symbol) -> Bool {
        halted.contains(symbol)
    }

    // MARK: - MarketControlling

    public func trigger(_ event: MarketEvent) {
        switch event {
        case let .crash(symbol, percent):
            let factor = 1 - NSDecimalNumber(decimal: percent).doubleValue / 100
            let targets = symbol.map { [$0] } ?? Array(prices.keys)
            for target in targets {
                prices[target] = prices[target].map { $0 * factor }
            }
            broadcastAllQuotes()

        case let .volatilitySpike(multiplier, duration):
            volatilityMultiplier = multiplier
            spikeTicksRemaining = ticks(in: duration)

        case let .halt(symbol):
            guard halted.insert(symbol).inserted else { return }
            broadcast(.halted(symbol))

        case let .resume(symbol):
            guard halted.remove(symbol) != nil else { return }
            broadcast(.resumed(symbol))
            if let quote = quote(for: symbol) { broadcast(.quote(quote)) }

        case let .dropFeed(duration):
            feedDropTicksRemaining = max(1, ticks(in: duration))
            broadcast(.feedInterrupted, force: true)
        }
    }

    // MARK: - Yardımcılar

    private func ticks(in duration: Duration) -> Int {
        Int((duration / configuration.tickInterval).rounded(.up))
    }

    private func broadcastAllQuotes() {
        for item in configuration.instruments where !halted.contains(item.instrument.symbol) {
            if let quote = quote(for: item.instrument.symbol) { broadcast(.quote(quote)) }
        }
    }

    /// Olayı ilgili abonelere yollar. Akış kopukken (`dropFeed`) sadece `force` olanlar gider.
    private func broadcast(_ update: MarketUpdate, force: Bool = false) {
        guard force || feedDropTicksRemaining == 0 else { return }
        for subscriber in subscribers.values where subscriber.wants(update) {
            subscriber.continuation.yield(update)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    /// Testler için: kaç abone var?
    var subscriberCount: Int { subscribers.count }

    /// Testler için: yuvarlanmamış iç fiyat.
    func rawPrice(of symbol: Symbol) -> Double? { prices[symbol] }
}
