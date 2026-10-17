/// Uygulamanın takip ettiği BIST hisseleri. Simülatör ve gerçek veri sağlayıcısı
/// aynı listeyi kullanır; böylece kaynak değişince ekrandaki hisseler değişmez.
public enum BistCatalog {
    public static let instruments: [Instrument] = [
        Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları"),
        Instrument(symbol: Symbol("ASELS"), name: "Aselsan"),
        Instrument(symbol: Symbol("GARAN"), name: "Garanti BBVA"),
        Instrument(symbol: Symbol("AKBNK"), name: "Akbank"),
        Instrument(symbol: Symbol("BIMAS"), name: "BİM Mağazalar"),
        Instrument(symbol: Symbol("KCHOL"), name: "Koç Holding"),
        Instrument(symbol: Symbol("SISE"), name: "Şişecam"),
        Instrument(symbol: Symbol("EREGL"), name: "Ereğli Demir Çelik"),
        Instrument(symbol: Symbol("TUPRS"), name: "Tüpraş"),
        Instrument(symbol: Symbol("FROTO"), name: "Ford Otosan"),
    ]
}
