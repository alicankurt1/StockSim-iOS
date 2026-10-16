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
        let sparklineValues = sparkline.map(PriceFormatting.chartValue)

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
            price: PriceFormatting.price(quote.price),
            change: PriceFormatting.changePercent(quote.changePercent),
            trend: PriceTrend(changePercent: quote.changePercent),
            sparkline: sparklineValues
        )
    }

    private static func monogram(for symbol: Symbol) -> String {
        String(symbol.rawValue.prefix(2))
    }

}
