/// Dağıtım derlemesinin (TestFlight) hisseleri: tamamen UYDURMA şirketler.
/// Gerçek şirket isimleri ve kodları kullanılmaz; böylece simüle fiyatlar gerçek bir
/// şirketin fiyatı sanılamaz. Kodlar gerçek borsa kodlarına benzemesin diye sesli harfsiz.
public enum FictionalCatalog {

    /// İlk açılıştaki izleme listesi.
    public static let instruments: [Instrument] = [
        ("NKHVC", "Anka Havacılık"), ("KLKSV", "Kalkan Savunma"), ("MVBNK", "Mavi Bank"),
        ("YLDZB", "Yıldız Yatırım Bankası"), ("SPTMG", "Sepetim Mağazaları"), ("CNRHL", "Çınar Holding"),
        ("CMSNC", "Camsan Cam"), ("DMRCL", "Demirçelik Sanayi"), ("RFNRY", "Rafineri Enerji"),
        ("TMKOT", "Otomak Otomotiv"),
    ].map { Instrument(symbol: Symbol($0.0), name: $0.1) }

    /// Aramada bulunabilen tüm hisseler.
    public static let directory: [Instrument] = instruments + [
        ("KRLTK", "Kartal Tekstil"), ("PRLNR", "Pırlanta Enerji"), ("DNZLJ", "Deniz Lojistik"),
        ("GNSPV", "Güneş Panel"), ("BLTGY", "Bulut Gayrimenkul"), ("TRKZT", "Turkuaz Telekom"),
        ("LMNGD", "Limon Gıda"), ("ZYTNY", "Zeytin Yağ Sanayi"), ("KYMKM", "Kayımkimya"),
        ("RZGRN", "Rüzgar Yenilenebilir"), ("PSLNT", "Pusula Teknoloji"), ("SMRBY", "Semerkand Boya"),
        ("KPKLT", "Kapadokya Turizm"), ("TLPHS", "Lale Hastaneleri"), ("BRKMD", "Bereket Madencilik"),
        ("MRJNS", "Mercan Sigorta"), ("YNCGM", "Yunus Gemi İnşa"), ("FNDKT", "Fındık Tarım"),
        ("KMPSY", "Kompas Yazılım"), ("TSKRB", "Taş Köprü Beton"),
    ].map { Instrument(symbol: Symbol($0.0), name: $0.1) }
}

/// Simülatörün kullandığı hisse evreni: ilk izleme listesi + aranabilir rehber.
/// Composition root hangisinin kullanılacağını seçer (geliştirme: BIST, dağıtım: kurgusal).
public struct MarketUniverse: Sendable {
    public let featured: [Instrument]
    public let directory: [Instrument]

    public init(featured: [Instrument], directory: [Instrument]) {
        self.featured = featured
        self.directory = directory
    }

    /// Gerçek BIST kodları, simüle fiyatlar (sadece geliştirme derlemesi).
    public static let bist = MarketUniverse(featured: BistCatalog.instruments, directory: BistDirectory.instruments)
    /// Uydurma şirketler (dağıtım derlemesi).
    public static let fictional = MarketUniverse(featured: FictionalCatalog.instruments, directory: FictionalCatalog.directory)
}
