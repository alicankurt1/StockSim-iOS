import Foundation
@testable import Domain

// Domain testlerinin ortak yardımcıları.

/// Testlerde Decimal'i string'den kur: `Decimal(0.1)` ya da `let d: Decimal = 0.1`
/// önce Double'dan geçer ve hassasiyet kaybolabilir.
func dec(_ string: String) -> Decimal {
    Decimal(string: string)!
}

func money(_ string: String) -> Money {
    Money(dec(string))
}
