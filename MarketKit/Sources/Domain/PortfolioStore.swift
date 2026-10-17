import Foundation

/// Uygulamanın tek sanal hesabı: birden fazla ekran (al/sat, portföy, geçmiş) aynı anda okur/yazar.
public protocol PortfolioStoring: Sendable {
    func currentPortfolio() async -> Portfolio
    @discardableResult
    func execute(_ order: Order, at quote: Quote) async throws -> Trade
    /// Hesabı başlangıç nakdine döndürür (tüm pozisyonlar ve geçmiş silinir).
    func reset() async
    /// Portföy her değiştiğinde yeni hali. Abone olunca önce güncel hal gelir.
    func changes() async -> AsyncStream<Portfolio>
}

/// Paylaşılan, değişen durum → actor.
///
/// `Portfolio` bir struct (değer tipi) ve kuralları biliyor; bu actor sadece "tek bir doğru
/// kopya"yı tutuyor ve erişimleri sıraya koyuyor. İki ekran aynı anda alım yapsa bile
/// nakit iki kez harcanamaz: ikinci emir, birincinin sonucunu görerek çalışır.
///
/// Kalıcılık: açılışta `repository`'den yükler, her değişiklikten sonra kaydeder.
public actor PortfolioStore: PortfolioStoring {

    private var portfolio: Portfolio
    private let startingCash: Money
    private let repository: PortfolioRepository?
    private var observers: [UUID: AsyncStream<Portfolio>.Continuation] = [:]

    /// Son kayıt hatası (varsa). İşlem yine de bellekte geçerli kalır; kullanıcı işlemini kaybetmez.
    public private(set) var lastSaveError: (any Error)?

    /// - Parameter repository: `nil` ise sadece bellekte tutulur (testler, önizlemeler).
    public init(initialCash: Money = Money(100_000), repository: PortfolioRepository? = nil) {
        self.startingCash = initialCash
        self.repository = repository
        // Kayıt okunamazsa (bozuk dosya, yeni şema) sıfırdan başla: uygulama açılmaya devam etsin.
        let restored = (try? repository?.load()) ?? nil
        self.portfolio = restored ?? Portfolio(cash: initialCash)
    }

    public func currentPortfolio() -> Portfolio {
        portfolio
    }

    @discardableResult
    public func execute(_ order: Order, at quote: Quote) throws -> Trade {
        // Kuralları Portfolio uyguluyor; hata olursa `portfolio` değişmeden kalır.
        let trade = try portfolio.execute(order, at: quote)
        didChange()
        return trade
    }

    public func reset() {
        portfolio = Portfolio(cash: startingCash)
        didChange()
    }

    public func changes() -> AsyncStream<Portfolio> {
        // Sadece en güncel hal önemli: yavaş dinleyicide eski haller birikmesin.
        let (stream, continuation) = AsyncStream.makeStream(of: Portfolio.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        continuation.yield(portfolio)
        return stream
    }

    /// Kaydet ve dinleyen tüm ekranlara yeni hali duyur.
    /// Kayıt senkron: arada `await` yok, bu yüzden başka bir emir araya giremez.
    private func didChange() {
        do {
            try repository?.save(portfolio)
            lastSaveError = nil
        } catch {
            lastSaveError = error
        }
        observers.values.forEach { $0.yield(portfolio) }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
