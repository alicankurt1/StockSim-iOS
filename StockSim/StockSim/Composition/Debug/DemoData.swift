import Foundation
import Domain

/// `-demoData`: ekran görüntüleri ve demo videoları için hazır, tekrarlanabilir bir hesap.
/// Bellekte çalışır; kayıtlı veriye dokunmaz. Fiyatlar simülatörün başlangıç fiyatlarına yakın.
enum DemoData {

    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-demoData") }

    private static let day: TimeInterval = 86_400

    private static func instrument(_ code: String) -> Instrument {
        BistCatalog.instruments.first { $0.symbol.rawValue == code }!
    }

    private static func quote(_ code: String, _ price: String, daysAgo: Double) -> Quote {
        let money = Money(Decimal(string: price)!)
        return Quote(symbol: Symbol(code), price: money, previousClose: money, timestamp: Date().addingTimeInterval(-daysAgo * day))
    }

    /// 100.000 ₺ ile açılmış, birkaç alım ve bir satış yapılmış hesap.
    static func portfolio() -> Portfolio {
        var portfolio = Portfolio(cash: Money(100_000))
        let trades: [(String, OrderSide, Int, String, Double)] = [
            ("THYAO", .buy, 60, "281.40", 21),
            ("ASELS", .buy, 150, "138.90", 14),
            ("BIMAS", .buy, 25, "498.00", 9),
            ("ASELS", .sell, 50, "143.20", 3),
        ]
        for (code, side, quantity, price, daysAgo) in trades {
            _ = try? portfolio.execute(Order(symbol: Symbol(code), side: side, quantity: quantity), at: quote(code, price, daysAgo: daysAgo))
        }
        return portfolio
    }

    static func scenarios() -> [WhatIfScenario] {
        [
            WhatIfScenario(instrument: instrument("AKBNK"), amount: Money(100_000), startDate: Date().addingTimeInterval(-240 * day), entryPrice: Money(Decimal(string: "52.30")!)),
            WhatIfScenario(instrument: instrument("THYAO"), amount: Money(50_000), startDate: Date().addingTimeInterval(-120 * day), entryPrice: Money(Decimal(string: "301.75")!)),
            WhatIfScenario(instrument: instrument("FROTO"), amount: Money(25_000), startDate: Date().addingTimeInterval(-30 * day), entryPrice: Money(912)),
        ]
    }

    /// Senaryoları okuyan ama hiçbir şey yazmayan depo.
    struct WhatIfRepository: Domain.WhatIfRepository {
        func load() throws -> [WhatIfScenario]? { DemoData.scenarios() }
        func save(_ scenarios: [WhatIfScenario]) throws {}
    }
}
