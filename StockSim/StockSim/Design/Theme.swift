import UIKit

/// Tasarım sistemi: renkler, fontlar, boşluklar tek yerde.
/// Ekranlar renk kodu yazmaz, buradan alır; tema değişince tek dosya değişir.
///
/// Palet: siyaha yakın lacivert zemin, lacivert kartlar, mavi vurgu.
/// Renkler dinamik (açık/koyu); uygulama şimdilik koyu modda açılıyor.
enum Theme {

    enum Color {
        /// Ekran zemini: siyaha yakın lacivert.
        static let background = UIColor.dynamic(light: UIColor(hex: 0xF4F7FC), dark: UIColor(hex: 0x070B14))
        /// Kart zemini.
        static let surface = UIColor.dynamic(light: .white, dark: UIColor(hex: 0x0F1729))
        /// Kart içindeki yükseltilmiş alanlar (rozet, pill).
        static let surfaceElevated = UIColor.dynamic(light: UIColor(hex: 0xEEF2F9), dark: UIColor(hex: 0x16213A))
        static let border = UIColor.dynamic(light: UIColor(hex: 0xDCE3EF), dark: UIColor(hex: 0x1C2742))

        static let textPrimary = UIColor.dynamic(light: UIColor(hex: 0x0B1220), dark: UIColor(hex: 0xF1F5F9))
        static let textSecondary = UIColor.dynamic(light: UIColor(hex: 0x5B6B86), dark: UIColor(hex: 0x8A9BB8))

        /// Vurgu: mavi.
        static let accent = UIColor.dynamic(light: UIColor(hex: 0x2563EB), dark: UIColor(hex: 0x3B82F6))
        static let up = UIColor.dynamic(light: UIColor(hex: 0x16A34A), dark: UIColor(hex: 0x22C55E))
        static let down = UIColor.dynamic(light: UIColor(hex: 0xE11D48), dark: UIColor(hex: 0xF43F5E))

        /// Skeleton kutularının zemini ve üzerinden geçen parıltı.
        static let skeleton = UIColor.dynamic(light: UIColor(hex: 0xE3E9F3), dark: UIColor(hex: 0x1A2540))
        static let skeletonHighlight = UIColor.dynamic(light: UIColor(hex: 0xF5F8FC), dark: UIColor(hex: 0x2A3A60))
    }

    enum Font {
        static let symbol = UIFont.systemFont(ofSize: 16, weight: .semibold)
        static let name = UIFont.systemFont(ofSize: 13, weight: .regular)
        /// Rakamlar sabit genişlikte: fiyat değişirken metin titremesin.
        static let price = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        static let change = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        static let monogram = UIFont.systemFont(ofSize: 13, weight: .bold)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
    }

    enum Radius {
        static let card: CGFloat = 14
        static let pill: CGFloat = 6
    }

    /// Navigation bar'ı temaya uydurur (büyük başlık dahil).
    static func style(_ navigationBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Color.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: Color.textPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: Color.textPrimary]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = Color.accent
    }
}

extension UIColor {

    /// 0xRRGGBB biçiminde renk.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// Açık ve koyu modda farklı görünen renk.
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }
}
