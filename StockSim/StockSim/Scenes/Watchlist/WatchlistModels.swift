import Domain

// VIP'de katmanlar arası taşınan veri tipleri. Her "kullanım senaryosu" (use case)
// için üçlü: Request (VC → Interactor), Response (Interactor → Presenter),
// ViewModel (Presenter → VC).
enum Watchlist {

    enum Load {
        /// Ekran açıldı, listeyi yükle. Şimdilik parametre yok.
        struct Request {}

        /// İş katmanının ham sonucu: Domain tipleri, format yok.
        struct Response {
            let instruments: [Instrument]
        }

        /// Ekrana hazır sonuç: sadece string ve enum. View hiçbir şey hesaplamaz.
        struct ViewModel {
            let rows: [Row]
        }
    }

    /// Listede bir satır. `Hashable`: diffable data source kimlik ve değişiklik takibi için ister.
    struct Row: Hashable {
        let id: Symbol
        let symbol: String
        let name: String
        let price: String
        let change: String
        let trend: PriceTrend
    }

    /// Renk kararı burada enum; `UIColor`'a çevirmek View'ın işi (Presenter UIKit bilmez).
    enum PriceTrend {
        case up, down, flat
    }
}
