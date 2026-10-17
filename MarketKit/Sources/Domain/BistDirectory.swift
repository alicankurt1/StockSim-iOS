import Foundation

/// Aranabilir BIST hisseleri rehberi (çevrimdışı). Simülatör modunda arama buradan yapılır;
/// gerçek veri modunda sağlayıcının kendi arama servisi kullanılır.
public enum BistDirectory {

    public static let instruments: [Instrument] = BistCatalog.instruments + [
        ("AKSA", "Aksa Akrilik"), ("AKSEN", "Aksa Enerji"), ("ALARK", "Alarko Holding"),
        ("ARCLK", "Arçelik"), ("ASTOR", "Astor Enerji"), ("BRSAN", "Borusan Boru"),
        ("CCOLA", "Coca-Cola İçecek"), ("DOAS", "Doğuş Otomotiv"), ("EKGYO", "Emlak Konut GYO"),
        ("ENKAI", "Enka İnşaat"), ("GUBRF", "Gübre Fabrikaları"), ("HEKTS", "Hektaş"),
        ("ISCTR", "İş Bankası (C)"), ("KONTR", "Kontrolmatik"), ("KRDMD", "Kardemir (D)"),
        ("MGROS", "Migros"), ("ODAS", "Odaş Elektrik"), ("OYAKC", "Oyak Çimento"),
        ("PETKM", "Petkim"), ("PGSUS", "Pegasus"), ("SAHOL", "Sabancı Holding"),
        ("SASA", "SASA Polyester"), ("SOKM", "Şok Marketler"), ("TAVHL", "TAV Havalimanları"),
        ("TCELL", "Turkcell"), ("TOASO", "Tofaş"), ("TTKOM", "Türk Telekom"),
        ("ULKER", "Ülker"), ("VAKBN", "VakıfBank"), ("VESTL", "Vestel"), ("YKBNK", "Yapı Kredi"),
    ].map { Instrument(symbol: Symbol($0.0), name: $0.1) }

    /// Kod ya da isimde geçen hisseler; kodu sorguyla başlayanlar önce.
    /// Türkçe harf farkları yok sayılır ("sise" → "Şişecam" bulunur).
    public static func search(_ query: String, in instruments: [Instrument] = instruments) -> [Instrument] {
        let needle = fold(query)
        guard !needle.isEmpty else { return [] }
        let matches = instruments.filter {
            fold($0.symbol.rawValue).contains(needle) || fold($0.name).contains(needle)
        }
        return matches.sorted { lhs, rhs in
            let left = fold(lhs.symbol.rawValue).hasPrefix(needle), right = fold(rhs.symbol.rawValue).hasPrefix(needle)
            if left != right { return left }
            return lhs.symbol.rawValue < rhs.symbol.rawValue
        }
    }

    /// Küçük harf + aksan/Türkçe harf sadeleştirme: "Şişecam" → "sisecam", "İŞ" → "is".
    static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .lowercased()
    }
}

/// Hisse arama (ISP: fiyat okumaktan ayrı küçük bir yetenek).
public protocol SymbolSearching: Sendable {
    func searchInstruments(matching query: String) async throws -> [Instrument]
}
