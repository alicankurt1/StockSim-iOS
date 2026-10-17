import Foundation
import Domain

/// "Ya alsaydım?" senaryo oluşturucu.
///
/// ```
///  Stock      [THYAO · Türk Hava Yolları ⌄]
///  Amount     ₺ [100.000]
///  Date       [12 Apr 2026]
/// ┌──────────────────────────────────────┐
/// │ Bought 347,83 shares at ₺287,50      │
/// │ ₺112.345,00                          │
/// │ +₺12.345,00 (+%12,35)                │
/// │      ╱╲  ╱‾‾╲ ╱                       │  grafik
/// │ - - ╱- -╲- - -╲- - - - (alım fiyatı)  │
/// └──────────────────────────────────────┘
///  [            Track this            ]
/// ```
enum WhatIfBuilder {

    enum Edit {
        struct Request {
            var instrument: Instrument?
            var date: Date?
            var amountText: String?
        }
    }

    struct Response {
        /// Var olan bir senaryo mu düzenleniyor (başlık ve düğme metni değişir)?
        let isEditing: Bool
        let instruments: [Instrument]
        let instrument: Instrument?
        let date: Date
        let dateRange: ClosedRange<Date>
        let amount: Money?
        let outcome: Outcome

        enum Outcome {
            case calculating
            case result(WhatIfScenario, currentPrice: Money, candles: [Candle])
            case invalidAmount
            case unavailable
        }
    }

    struct ViewModel: Equatable {
        let title: String
        let trackTitle: String
        /// Tutar alanının metni (düzenlemede dolu gelir).
        let amountText: String
        let stockTitle: String
        let stockOptions: [StockOption]
        let date: Date
        let dateRange: ClosedRange<Date>
        let result: Result?
        /// Sonuç yerine gösterilecek mesaj.
        let message: String?
        let isCalculating: Bool
        let isTrackEnabled: Bool
    }

    struct StockOption: Equatable {
        let instrument: Instrument
        let title: String
        let isSelected: Bool
    }

    struct Result: Equatable {
        /// "Bought 347,83 shares at ₺287,50 on 12 Apr 2026"
        let entry: String
        let value: String
        let profitLoss: String
        let trend: PriceTrend
        let chart: [Double]
        /// Alım fiyatı: grafikte kesikli çizgi.
        let baseline: Double
    }

    enum Track {
        struct Response {
            let scenario: WhatIfScenario
        }
    }
}
