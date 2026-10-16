import Domain

/// Al/sat formu. Her değişiklikte (taraf, adet, canlı fiyat, işlem durdurma) form
/// baştan hesaplanıp tek bir ViewModel olarak gösterilir: ekranın durumu tek kaynaktan gelir.
enum TradeTicket {

    /// Ekran açıldı: hesap ve fiyat yüklensin.
    enum Load {
        struct Request {}
    }

    /// Kullanıcı formu değiştirdi.
    enum Edit {
        struct Request {
            var side: OrderSide?
            var quantity: Int?
        }
    }

    /// Onay düğmesine basıldı.
    enum Submit {
        struct Request {}

        struct Response {
            let trade: Trade
        }

        struct ViewModel: Equatable {
            let message: String
        }
    }

    /// Formun ham durumu (Interactor → Presenter).
    struct FormResponse {
        let instrument: Instrument
        let side: OrderSide
        let quantity: Int
        let quote: Quote?
        let cash: Money
        let ownedQuantity: Int
        /// Emir şu an gönderilse hangi kurala takılırdı? `nil` = gönderilebilir.
        let error: TradingError?
    }

    /// Formun ekrana hazır hali.
    struct FormViewModel: Equatable {
        let title: String
        let selectedSideIndex: Int
        /// Hisse yoksa "Sell" seçilemez.
        let isSellEnabled: Bool
        let price: String
        let quantityText: String
        let estimatedTotal: String
        /// "Cash available ₺100.000,00" ya da "You own 10 shares".
        let availability: String
        /// Kural ihlali mesajı; `nil` ise gösterilmez.
        let errorMessage: String?
        let submitTitle: String
        let isSubmitEnabled: Bool
    }
}
