import Domain

/// Interactor'ın Presenter'a verebileceği sonuçlar.
@MainActor
protocol WatchlistPresentationLogic {
    func presentWatchlist(response: Watchlist.Load.Response)
    func presentLoadError()
}

/// Presenter: Domain verisini ekrana hazır ViewModel'e çevirir (format, renk kararı).
/// UIKit import ETMEZ; bu yüzden UI olmadan test edilebilir.
@MainActor
final class WatchlistPresenter: WatchlistPresentationLogic {

    /// `weak`: VC → Interactor → Presenter → VC zincirinde döngüsel referans olmasın.
    weak var viewController: WatchlistDisplayLogic?

    func presentWatchlist(response: Watchlist.Load.Response) {
        // Adım 2'de fiyat ve değişim formatlanacak; şimdilik sadece kod ve isim.
        let rows = response.instruments.map { instrument in
            Watchlist.Row(
                id: instrument.symbol,
                symbol: instrument.symbol.rawValue,
                name: instrument.name,
                price: "—",
                change: "",
                trend: .flat
            )
        }
        viewController?.displayWatchlist(viewModel: Watchlist.Load.ViewModel(rows: rows))
    }

    func presentLoadError() {
        viewController?.displayLoadError(message: "Couldn't load the watchlist.")
    }
}
