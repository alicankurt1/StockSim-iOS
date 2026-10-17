import Domain

enum StockDetail {

    /// Ekran ilk açılırken (henüz veri yüklenmeden): Router'ın aktardığı bilgiyle başlık dolu gelsin.
    enum Initial {
        struct Response {
            let instrument: Instrument
            let quote: Quote?
        }

        struct ViewModel: Equatable {
            let title: String
            let header: Header?
        }
    }

    /// Kullanıcının bu hissedeki pozisyonu: portföy ya da fiyat değişince yenilenir.
    enum Holding {
        struct Response {
            let position: Position?
            let quote: Quote?
        }

        struct ViewModel: Equatable {
            /// `nil`: hissede pozisyon yok → kart gizli.
            let card: Card?
            /// Pozisyon yoksa sadece "Buy" görünür.
            let canSell: Bool

            struct Card: Equatable {
                /// "4 shares · Avg ₺287,50"
                let summary: String
                /// Güncel değer, ör. "₺1.150,00"
                let value: String
                /// "+₺12,00 (+%1,04)"
                let profitLoss: String
                let trend: PriceTrend
            }
        }
    }

    /// Ekran açıldı ya da aralık (1D/1W/1M/1Y) değişti.
    enum Load {
        struct Request {
            let range: ChartRange
        }

        struct Response {
            let instrument: Instrument
            let quote: Quote
            let candles: [Candle]
            let range: ChartRange
        }

        struct ViewModel: Equatable {
            /// Navigation bar başlığı: hisse kodu.
            let title: String
            let header: Header
            let chart: Chart
            /// Aralık seçicinin başlıkları ve seçili olan.
            let rangeTitles: [String]
            let selectedRangeIndex: Int
            /// Aralık boyunca değişim (ör. "+%3,20 · Past month").
            let rangeChange: String
            let rangeTrend: PriceTrend
            let high: String
            let low: String
        }
    }

    /// Canlı fiyat: başlık ve grafiğin ucu güncellenir.
    enum Update {
        struct Request {}

        struct Response {
            let quote: Quote
            let candles: [Candle]
            let range: ChartRange
        }

        struct ViewModel: Equatable {
            let header: Header
            let chart: Chart
            /// Aralık değişimi de canlı: grafiğin ucu oynadıkça değişir.
            let rangeChange: String
            let rangeTrend: PriceTrend
        }
    }

    /// Piyasa durumu: işlem durdurma ve akış kopması.
    enum MarketStatus {
        struct Response {
            let isHalted: Bool
            let isFeedInterrupted: Bool
        }

        struct ViewModel: Equatable {
            /// Alttaki uyarı şeridi; `nil` ise gizli.
            let bannerMessage: String?
            /// İşlem durdurulduysa al/sat kapalı.
            let isTradingEnabled: Bool
        }
    }

    /// Crosshair: parmağın altındaki nokta seçildi (ya da bırakıldı → `nil`).
    enum Select {
        struct Request {
            let index: Int?
        }

        enum Response {
            /// Seçili mum ve aralığın başlangıç fiyatı (değişim ona göre).
            case point(Candle, rangeStart: Money, range: ChartRange)
            /// Seçim bitti: başlık canlı fiyata döner.
            case cleared(name: String, quote: Quote)
        }

        struct ViewModel: Equatable {
            let header: Header
        }
    }

    struct Header: Equatable {
        let name: String
        let price: String
        let dayChange: String
        let dayTrend: PriceTrend
    }

    struct Chart: Equatable {
        /// Her nokta için açılış/en yüksek/en düşük/kapanış. Çizgi sadece kapanışı kullanır.
        let points: [Point]
        /// Gün içi grafikte önceki kapanış çizgisi; diğer aralıklarda yok.
        let baseline: Double?
        let trend: PriceTrend

        /// Ekrana hazır mum değerleri: sadece sayı (UIKit yok).
        struct Point: Equatable {
            let open: Double
            let high: Double
            let low: Double
            let close: Double
        }
    }
}
