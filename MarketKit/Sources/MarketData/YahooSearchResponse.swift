// Sadece Debug derlemesi (Package.swift → REAL_DATA).
#if REAL_DATA
/// Yahoo arama yanıtı (sadece kullandığımız alanlar). Alanlar eksik gelebilir → opsiyonel.
struct YahooSearchResponse: Decodable {
    let quotes: [Item]?

    struct Item: Decodable {
        let symbol: String
        let shortname: String?
        let longname: String?
        let quoteType: String?
    }
}
#endif
