import Foundation
import Domain

/// `-demoData`: ekran görüntüleri ve demo videoları için hazır, tekrarlanabilir bir hesap.
/// Bellekte çalışır; kayıtlı veriye dokunmaz. Fiyatlar simülatörün başlangıç fiyatlarına yakın.
enum DemoData {

    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }

    private static let day: TimeInterval = 86_400

    /// Demo hisseleri katalogdaki sıraya göre seçilir; böylece hem BIST hem kurgusal evrende
    /// çalışır ve fiyatlar simülatörün başlangıç fiyatlarına yakın kalır (aynı sıra, aynı davranış).
    private static func instrument(_ index: Int) -> Instrument {
        Distribution.universe.featured[index]
    }

    private static func quote(_ symbol: Symbol, _ price: String, daysAgo: Double) -> Quote {
        let money = Money(Decimal(string: price)!)
        return Quote(symbol: symbol, price: money, previousClose: money, timestamp: Date().addingTimeInterval(-daysAgo * day))
    }

    /// 100.000 ₺ ile açılmış, birkaç alım ve bir satış yapılmış hesap.
    static func portfolio() -> Portfolio {
        var portfolio = Portfolio(cash: Money(100_000))
        // 0: THYAO / Anka, 1: ASELS / Kalkan, 4: BIMAS / Sepetim
        let trades: [(Int, OrderSide, Int, String, Double)] = [
            (0, .buy, 60, "281.40", 21),
            (1, .buy, 150, "138.90", 14),
            (4, .buy, 25, "498.00", 9),
            (1, .sell, 50, "143.20", 3),
        ]
        for (index, side, quantity, price, daysAgo) in trades {
            let symbol = instrument(index).symbol
            _ = try? portfolio.execute(Order(symbol: symbol, side: side, quantity: quantity), at: quote(symbol, price, daysAgo: daysAgo))
        }
        return portfolio
    }

    /// 3: AKBNK / Yıldız, 0: THYAO / Anka, 9: FROTO / Otomak
    static func scenarios() -> [WhatIfScenario] {
        [
            WhatIfScenario(instrument: instrument(3), amount: Money(100_000), startDate: Date().addingTimeInterval(-240 * day), entryPrice: Money(Decimal(string: "52.30")!)),
            WhatIfScenario(instrument: instrument(0), amount: Money(50_000), startDate: Date().addingTimeInterval(-120 * day), entryPrice: Money(Decimal(string: "301.75")!)),
            WhatIfScenario(instrument: instrument(9), amount: Money(25_000), startDate: Date().addingTimeInterval(-30 * day), entryPrice: Money(912)),
        ]
    }

    /// Senaryoları okuyan ama hiçbir şey yazmayan depo.
    struct WhatIfRepository: Domain.WhatIfRepository {
        func load() throws -> [WhatIfScenario]? { DemoData.scenarios() }
        func save(_ scenarios: [WhatIfScenario]) throws {}
    }
}
