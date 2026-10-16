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

    struct Header: Equatable {
        let name: String
        let price: String
        let dayChange: String
        let dayTrend: PriceTrend
    }

    struct Chart: Equatable {
        let values: [Double]
        /// Gün içi grafikte önceki kapanış çizgisi; diğer aralıklarda yok.
        let baseline: Double?
        let trend: PriceTrend
    }
}
