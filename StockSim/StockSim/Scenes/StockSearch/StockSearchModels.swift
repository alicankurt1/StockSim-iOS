import Domain

/// Hisse arama ekranı.
///
/// Durumlar (her biri ayrı bir ViewModel; VC sadece gösterir):
/// - idle: arama kutusu boş → önerilen hisseler
/// - loading: istek yolda → dönen tekerlek
/// - results: sonuçlar
/// - empty: "xyz için sonuç yok"
/// - failed: ağ hatası
enum StockSearch {

    enum Query {
        struct Request {
            let text: String
        }
    }

    enum Add {
        struct Request {
            let instrument: Instrument
        }
    }

    struct Response {
        enum State {
            case idle(suggestions: [Instrument])
            case loading
            case results([Instrument])
            case empty(query: String)
            case failed
        }

        let state: State
        /// İzleme listesinde zaten olanlar: satırda "eklendi" işareti için.
        let watchlist: Set<Symbol>
    }

    struct ViewModel: Equatable {
        /// Liste başlığı ("Popular", "Results") ya da `nil`.
        let sectionTitle: String?
        let rows: [Row]
        /// Liste yerine gösterilecek mesaj (boş sonuç, hata, ipucu).
        let message: String?
        let isLoading: Bool
    }

    struct Row: Hashable {
        let id: Symbol
        let symbol: String
        let name: String
        let isAdded: Bool
        /// Satıra dokununca eklenecek hisse (Presenter'dan VC'ye, oradan Interactor'a geri döner).
        let instrument: Instrument
    }
}
