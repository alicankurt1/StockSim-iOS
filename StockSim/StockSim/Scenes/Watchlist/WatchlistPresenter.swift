import Foundation
import Domain

/// Interactor'ın Presenter'a verebileceği sonuçlar.
@MainActor
protocol WatchlistPresentationLogic {
    func presentLoading()
    func presentWatchlist(response: Watchlist.Load.Response)
    func presentLoadError()
    func presentQuoteUpdate(response: Watchlist.Update.Response)
}

/// Presenter: Domain verisini ekrana hazır ViewModel'e çevirir (format, renk kararı).
/// UIKit import ETMEZ; bu yüzden UI olmadan test edilebilir.
@MainActor
final class WatchlistPresenter: WatchlistPresentationLogic {

    /// `weak`: VC → Interactor → Presenter → VC zincirinde döngüsel referans olmasın.
    weak var viewController: WatchlistDisplayLogic?

    /// Kaç skeleton satırı gösterileceği: ekranı dolduracak kadar.
    static let placeholderCount = 8

    func presentLoading() {
        let items = (0..<Self.placeholderCount).map(Watchlist.Item.placeholder)
        viewController?.displayWatchlist(viewModel: Watchlist.Load.ViewModel(items: items))
    }

    func presentWatchlist(response: Watchlist.Load.Response) {
        let items = response.instruments.map { instrument in
            Watchlist.Item.stock(makeRow(
                instrument: instrument,
                quote: response.quotes[instrument.symbol],
                sparkline: response.sparklines[instrument.symbol] ?? []
            ))
        }
        viewController?.displayWatchlist(viewModel: Watchlist.Load.ViewModel(items: items))
    }

    func presentLoadError() {
        viewController?.displayLoadError(message: "Couldn't load the watchlist.")
    }

    func presentQuoteUpdate(response: Watchlist.Update.Response) {
        let row = makeRow(instrument: response.instrument, quote: response.quote, sparkline: response.sparkline)
        viewController?.displayQuoteUpdate(viewModel: Watchlist.Update.ViewModel(row: row))
    }

    // MARK: - Satır

    /// Bir hisseyi ekrana hazır satıra çevirir.
    func makeRow(instrument: Instrument, quote: Quote?, sparkline: [Money] = []) -> Watchlist.Row {
        // Çizim için Double yeterli; hassas para hesabı burada yapılmıyor.
        let sparklineValues = sparkline.map { NSDecimalNumber(decimal: $0.amount).doubleValue }

        // Fiyat henüz gelmediyse yer tutucu göster.
        guard let quote else {
            return Watchlist.Row(
                id: instrument.symbol,
                symbol: instrument.symbol.rawValue,
                monogram: Self.monogram(for: instrument.symbol),
                name: instrument.name,
                price: "—",
                change: "",
                trend: .flat,
                sparkline: sparklineValues
            )
        }

        return Watchlist.Row(
            id: instrument.symbol,
            symbol: instrument.symbol.rawValue,
            monogram: Self.monogram(for: instrument.symbol),
            name: instrument.name,
            price: Self.formatPrice(quote.price),
            change: Self.formatChangePercent(quote.changePercent),
            trend: Self.trend(for: quote.changePercent),
            sparkline: sparklineValues
        )
    }

    private static func monogram(for symbol: Symbol) -> String {
        String(symbol.rawValue.prefix(2))
    }

    /// Renk kararı: sadece yön. Hangi rengin çizileceğine VC karar verir.
    private static func trend(for changePercent: Decimal) -> Watchlist.PriceTrend {
        if changePercent > 0 { return .up }
        if changePercent < 0 { return .down }
        return .flat
    }

    // MARK: - Formatlama (hazır)

    /// "₺1.234,50": Türk lirası, Türkçe sayı biçimi.
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.currencyCode = "TRY"
        return formatter
    }()

    /// "%1,14": değer zaten yüzde olduğu için 100 ile çarpılmaz (multiplier = 1).
    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.multiplier = 1
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter
    }()

    static func formatPrice(_ money: Money) -> String {
        priceFormatter.string(from: money.amount as NSDecimalNumber) ?? "—"
    }

    /// İşaretli yüzde: "+%1,14", "-%0,52", "%0,00".
    static func formatChangePercent(_ percent: Decimal) -> String {
        let text = percentFormatter.string(from: percent as NSDecimalNumber) ?? ""
        return percent > 0 ? "+" + text : text
    }
}
