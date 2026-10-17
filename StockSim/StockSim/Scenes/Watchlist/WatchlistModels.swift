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
            /// Fiyatı henüz bilinmeyen hisse burada olmayabilir.
            let quotes: [Symbol: Quote]
            /// Gün içi kapanışlar (sparkline için). Eksik olabilir.
            var sparklines: [Symbol: [Money]] = [:]
        }

        /// Ekrana hazır sonuç: sadece string ve enum. View hiçbir şey hesaplamaz.
        struct ViewModel {
            let items: [Item]
            /// Liste boşsa gösterilecek yönlendirme; doluysa `nil`.
            var emptyMessage: String? = nil

            /// Sadece veri satırları (testler ve okunabilirlik için).
            var rows: [Row] {
                items.compactMap { item in
                    if case let .stock(row) = item { row } else { nil }
                }
            }
        }
    }

    /// Canlı fiyat güncellemesi: tek bir satır değişir.
    enum Update {
        /// Ekran göründü, canlı akışı başlat.
        struct Request {}

        struct Response {
            let instrument: Instrument
            let quote: Quote
            /// Son değeri canlı fiyatla güncellenmiş gün içi seri.
            var sparkline: [Money] = []
        }

        struct ViewModel {
            let row: Row
        }
    }

    /// Kullanıcı bir hisseyi listeden çıkardı (kaydırarak ya da düzenleme modunda).
    enum Remove {
        struct Request {
            let symbol: Symbol
        }
    }

    /// Kullanıcı listeyi sürükleyerek yeniden sıraladı.
    enum Reorder {
        struct Request {
            let symbols: [Symbol]
        }
    }

    /// Listedeki bir öğe: ya yükleniyor kutusu (skeleton) ya da gerçek satır.
    /// Yükleniyor durumu da bir ViewModel; VC kendi kafasına göre spinner göstermez.
    enum Item: Hashable {
        case placeholder(Int)
        case stock(Row)
    }

    /// Listede bir satır. `Hashable`: diffable data source kimlik ve değişiklik takibi için ister.
    struct Row: Hashable {
        let id: Symbol
        let symbol: String
        /// Rozette görünen iki harf (ör. "TH").
        let monogram: String
        let name: String
        let price: String
        let change: String
        let trend: PriceTrend
        /// Sparkline değerleri. Sadece sayı: nasıl çizileceği View'ın işi.
        let sparkline: [Double]
    }
}
