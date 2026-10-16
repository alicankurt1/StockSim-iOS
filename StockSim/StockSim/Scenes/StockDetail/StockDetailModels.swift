import Domain

enum StockDetail {

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
