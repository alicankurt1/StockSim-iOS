import Foundation
import Domain

/// Dağıtım (TestFlight) derlemesinin kuralları tek yerde.
///
/// Release derlemesi (Archive) her zaman dağıtım derlemesidir: gerçek veri kodu derlemeye
/// hiç girmez (`#if DEBUG`), hisseler uydurma şirketlerdir. Geliştirmede aynı davranışı
/// denemek için `-distribution` argümanı kullanılır.
enum Distribution {

    #if DEBUG
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-distribution")
    #else
    static let isEnabled = true
    #endif

    /// Simülatörün hisse evreni: geliştirmede gerçek BIST kodları, dağıtımda kurgusal şirketler.
    static var universe: MarketUniverse { isEnabled ? .fictional : .bist }

    static let repositoryURL = URL(string: "https://github.com/alicankurt1/StockSim-iOS")!
}
