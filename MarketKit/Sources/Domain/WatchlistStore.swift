import Foundation

/// İzleme listesinin kalıcı saklandığı yer. Portföy deposu gibi bilerek senkron.
public protocol WatchlistRepository: Sendable {
    func load() throws -> [Instrument]?
    func save(_ instruments: [Instrument]) throws
}

public protocol WatchlistStoring: Sendable {
    func current() async -> [Instrument]
    func add(_ instrument: Instrument) async
    func remove(_ symbol: Symbol) async
    /// Kullanıcının sürükleyerek verdiği yeni sıra.
    func reorder(_ symbols: [Symbol]) async
    /// Liste her değiştiğinde yeni hali; abone olunca önce güncel hal gelir.
    func changes() async -> AsyncStream<[Instrument]>
}

/// Kullanıcının kişisel izleme listesi: sadece buradaki hisseler canlı takip edilir.
/// Paylaşılan, değişen durum (Watchlist ve arama ekranı aynı anda kullanır) → actor.
public actor WatchlistStore: WatchlistStoring {

    private var instruments: [Instrument]
    private let repository: WatchlistRepository?
    private var observers: [UUID: AsyncStream<[Instrument]>.Continuation] = [:]

    /// İlk açılışta kayıt yoksa varsayılan liste (`BistCatalog`).
    public init(defaults: [Instrument] = BistCatalog.instruments, repository: WatchlistRepository? = nil) {
        self.repository = repository
        self.instruments = ((try? repository?.load()) ?? nil) ?? defaults
    }

    public func current() -> [Instrument] {
        instruments
    }

    public func add(_ instrument: Instrument) {
        guard !instruments.contains(where: { $0.symbol == instrument.symbol }) else { return }
        instruments.append(instrument)
        didChange()
    }

    public func remove(_ symbol: Symbol) {
        let before = instruments.count
        instruments.removeAll { $0.symbol == symbol }
        if instruments.count != before { didChange() }
    }

    public func reorder(_ symbols: [Symbol]) {
        let bySymbol = Dictionary(instruments.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
        // Verilen sıradakiler önce; verilmeyenler (olmaması gerekir) sona, eski sırasıyla.
        let ordered = symbols.compactMap { bySymbol[$0] }
        let rest = instruments.filter { !symbols.contains($0.symbol) }
        let updated = ordered + rest
        guard updated != instruments else { return }
        instruments = updated
        didChange()
    }

    public func changes() -> AsyncStream<[Instrument]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Instrument].self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        continuation.yield(instruments)
        return stream
    }

    private func didChange() {
        try? repository?.save(instruments)
        observers.values.forEach { $0.yield(instruments) }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
