import Foundation

/// Hisse kodu (ör. "THYAO").
///
/// Neden düz `String` değil? Tip güvenliği: bir fonksiyon `Symbol` istiyorsa
/// yanlışlıkla şirket adını ya da başka bir metni veremezsin. Ayrıca normalleştirme
/// ("  thyao " → "THYAO") tek bir yerde yapılır.
public struct Symbol: Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(_ rawValue: String) {
        // Baştaki/sondaki boşlukları kırp, büyük harfe çevir.
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public var description: String { rawValue }
}
