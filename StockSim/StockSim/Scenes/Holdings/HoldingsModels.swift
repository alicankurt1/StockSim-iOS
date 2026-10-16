import Foundation
import Domain

/// Portföy sekmesi. (Domain'deki `Portfolio` tipiyle karışmasın diye sahnenin adı "Holdings".)
///
/// ```
/// ┌ Hesap kartı ─────────────────┐
/// │ Total value     ₺101.234,50  │
/// │ +₺1.234,50 (+%1,23) all time │
/// │ Cash ₺95.000   Invested ₺6.2k│
/// └──────────────────────────────┘
///  Positions
///  (TH) THYAO  4 shares · Avg …   ₺1.150  +%1,04
///  Activity
///  (↑) Bought 4 THYAO  16 Oct 14:39   -₺1.150,00
/// ```
enum Holdings {

    /// Hesap, fiyat ya da işlem geçmişi her değiştiğinde ekranın tamamı yeniden hesaplanır.
    enum Load {
        struct Response {
            let portfolio: Portfolio
            let quotes: [Symbol: Quote]
            let names: [Symbol: String]
        }

        struct ViewModel: Equatable {
            let account: AccountCard
            let positions: [PositionRow]
            let activity: [ActivityRow]
        }
    }

    struct AccountCard: Equatable {
        let totalValue: String
        /// Başlangıç nakdinden bu yana: "+₺1.234,50 (+%1,23)".
        let totalProfitLoss: String
        let trend: PriceTrend
        let cash: String
        let invested: String
    }

    struct PositionRow: Equatable {
        let id: Symbol
        let symbol: String
        let monogram: String
        /// "4 shares · Avg ₺287,50"
        let summary: String
        let value: String
        /// "+₺12,00 (+%1,04)"
        let profitLoss: String
        let trend: PriceTrend
    }

    struct ActivityRow: Equatable {
        let id: UUID
        /// "Bought 4 THYAO"
        let title: String
        /// "16 Oct, 14:39 · ₺287,50"
        let subtitle: String
        /// Nakit hareketi: alım "-₺1.150,00", satış "+₺602,70".
        let amount: String
        let side: OrderSide
    }
}
