import Foundation

/// Uygulamanın tek sanal hesabı: birden fazla ekran (al/sat, portföy, geçmiş) aynı anda okur/yazar.
public protocol PortfolioStoring: Sendable {
    func currentPortfolio() async -> Portfolio
    @discardableResult
    func execute(_ order: Order, at quote: Quote) async throws -> Trade
    /// Portföy her değiştiğinde yeni hali. Abone olunca önce güncel hal gelir.
    func changes() async -> AsyncStream<Portfolio>
}

/// Paylaşılan, değişen durum → actor.
///
/// `Portfolio` bir struct (değer tipi) ve kuralları biliyor; bu actor sadece "tek bir doğru
/// kopya"yı tutuyor ve erişimleri sıraya koyuyor. İki ekran aynı anda alım yapsa bile
/// nakit iki kez harcanamaz: ikinci emir, birincinin sonucunu görerek çalışır.
/// Phase 8'de buraya kalıcılık (dosyaya yazma) eklenecek.
public actor PortfolioStore: PortfolioStoring {

    private var portfolio: Portfolio
    private var observers: [UUID: AsyncStream<Portfolio>.Continuation] = [:]

    public init(initialCash: Money = Money(100_000)) {
        portfolio = Portfolio(cash: initialCash)
    }

    public func currentPortfolio() -> Portfolio {
        portfolio
    }

    @discardableResult
    public func execute(_ order: Order, at quote: Quote) throws -> Trade {
        // Kuralları Portfolio uyguluyor; hata olursa `portfolio` değişmeden kalır.
        let trade = try portfolio.execute(order, at: quote)
        // Başarılıysa dinleyen tüm ekranlara yeni hali duyur (ör. detaydaki "Sell" düğmesi).
        observers.values.forEach { $0.yield(portfolio) }
        return trade
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

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
