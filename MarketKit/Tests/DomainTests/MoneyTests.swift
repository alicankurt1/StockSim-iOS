import Foundation
import Testing
@testable import Domain

struct MoneyTests {

    // MARK: - Neden Decimal? (kavram testleri, örnek olarak yazıldı)

    @Test func doubleCannotRepresentTenthsExactly() {
        #expect(0.1 + 0.2 != 0.3)
    }

    @Test func decimalAddsTenthsExactly() {
        #expect(dec("0.1") + dec("0.2") == dec("0.3"))
    }

    // MARK: - Toplama (parametreli test örneği)

    /// Her satır ayrı bir test olarak koşar; biri bozulursa hangi satır olduğu raporda görünür.
    @Test(arguments: [
        ("100.00", "50.25", "150.25"),
        ("0.10", "0.20", "0.30"),
        ("287.50", "0", "287.50"),
    ])
    func addition(lhs: String, rhs: String, expected: String) {
        #expect(money(lhs) + money(rhs) == money(expected))
    }

    // MARK: - Çıkarma

    /// Son satır: sonuç negatif olabilir (zarar durumu), Money bunu engellemez.
    @Test(arguments: [
        ("150.25", "50.25", "100.00"),
        ("0.30", "0.10", "0.20"),
        ("10", "25", "-15"),
    ])
    func subtraction(lhs: String, rhs: String, expected: String) {
        #expect(money(lhs) - money(rhs) == money(expected))
    }

    // MARK: - Adetle çarpma

    /// (birim fiyat, adet, beklenen toplam)
    @Test(arguments: [
        ("287.50", 10, "2875.00"),
        ("0.05", 3, "0.15"),
        ("99.99", 0, "0"),
    ])
    func multiplicationByQuantity(price: String, quantity: Int, expected: String) {
        #expect(money(price) * quantity == money(expected))
    }

    // MARK: - Karşılaştırma

    @Test func comparison() {
        // Bir kuruş fark bile yakalanmalı.
        #expect(money("10") < money("10.01"))
        #expect(!(money("10.01") < money("10")))

        // Eşit değerler birbirinden küçük değildir; `==` ise sondaki sıfırlara bakmaz.
        #expect(!(money("10") < money("10.00")))
        #expect(money("10") == money("10.00"))
    }

    // MARK: - Sıfır

    @Test func zeroIsIdentity() {
        let price = money("287.50")
        #expect(price + .zero == price)
        #expect(price - .zero == price)
    }
}
