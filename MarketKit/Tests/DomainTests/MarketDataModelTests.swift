import Foundation
import Testing
@testable import Domain

struct SymbolTests {

    @Test(arguments: [
        ("THYAO", "THYAO"),
        ("thyao", "THYAO"),
        ("  asels ", "ASELS"),
    ])
    func normalizes(input: String, expected: String) {
        #expect(Symbol(input).rawValue == expected)
    }

    /// Normalleştirme sayesinde farklı yazımlar aynı hisseyi gösterir.
    @Test func sameCodeIsEqual() {
        #expect(Symbol("thyao") == Symbol("THYAO"))
    }
}

struct QuoteTests {

    /// Test için Quote kurmayı kısaltan yardımcı.
    private func quote(price: String, previousClose: String) -> Quote {
        Quote(
            symbol: Symbol("THYAO"),
            price: money(price),
            previousClose: money(previousClose),
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    /// (price, previousClose, beklenen change): yükselen, düşen, değişmeyen.
    @Test(arguments: [
        ("287.50", "284.25", "3.25"),
        ("90", "100", "-10"),
        ("50", "50", "0"),
    ])
    func change(price: String, previousClose: String, expected: String) {
        #expect(quote(price: price, previousClose: previousClose).change == money(expected))
    }

    /// (price, previousClose, beklenen yüzde): tam bölünen sayılar.
    @Test(arguments: [
        ("110", "100", "10"),
        ("150", "200", "-25"),
        ("50", "50", "0"),
        ("100.5", "100", "0.5"),
    ])
    func changePercent(price: String, previousClose: String, expected: String) {
        #expect(quote(price: price, previousClose: previousClose).changePercent == dec(expected))
    }

    /// Sıfıra bölme çökme yerine 0 vermeli.
    @Test func changePercentIsZeroWhenPreviousCloseIsZero() {
        #expect(quote(price: "10", previousClose: "0").changePercent == 0)
    }
}

struct CandleTests {

    /// (open, close, beklenen): yükselen, düşen, eşit (eşit = yükselen sayılır).
    @Test(arguments: [
        ("100", "105", true),
        ("100", "95", false),
        ("100", "100", true),
    ])
    func isBullish(open: String, close: String, expected: Bool) {
        // high/low bu kural için önemsiz; geçerli bir mum olsun diye uç değerler verildi.
        let candle = Candle(
            date: Date(timeIntervalSince1970: 0),
            open: money(open),
            high: money("200"),
            low: money("0"),
            close: money(close)
        )
        #expect(candle.isBullish == expected)
    }
}
