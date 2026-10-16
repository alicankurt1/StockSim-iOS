import UIKit

/// Ekranlar arası geçişler. Phase 5'te hisse detayına geçiş buraya gelecek.
@MainActor
protocol WatchlistRoutingLogic {}

@MainActor
final class WatchlistRouter: WatchlistRoutingLogic {

    /// `weak`: VC zaten Router'ı tutuyor.
    weak var viewController: UIViewController?
    /// Detay ekranına veri taşırken okunacak (DataPassing).
    let dataStore: WatchlistDataStore

    init(dataStore: WatchlistDataStore) {
        self.dataStore = dataStore
    }
}
