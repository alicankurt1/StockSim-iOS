# Öğrenme Notları

Her fazın sonunda sorulan soruların düzeltilmiş cevapları. Amaç: kavramları kendi cümlelerimle anlatabilmek.

## Proje başı kararları

**Neden Alamofire yok?**
Tek bir GET isteği atıyoruz. `URLSession` async/await ile bunu birkaç satırda yapıyor. Alamofire'ın güçlü olduğu interceptor, retry, multipart gibi özelliklere ihtiyacımız yok. Küçük bir `HTTPClient` protokolü yazmak hem bağımlılığı ortadan kaldırıyor hem de DIP'i ve sahte client'la test etmeyi doğrudan gösteriyor.

**Neden gerçek veri için Yahoo, neden doğrudan BIST değil?**
BIST veriyi ücretsiz API olarak sunmuyor. Resmi veri lisanslı dağıtıcılar üzerinden ve ücretli. Kapanış fiyatı her kaynakta aynı, risk verinin doğruluğunda değil endpoint'in değişmesinde. Bu yüzden veri kaynağı `MarketDataProviding` protokolünün arkasında. Kaynak değişirse sadece yeni bir provider yazılıyor (OCP + DIP).

**Neden iOS 16?**
Geniş cihaz desteği için. Daha yeni API'ler (`registerForTraitChanges`, UIKit `#Preview`) `@available` ile kullanılacak.

## Phase 0 — Foundation

**Composition root nedir? Clean Swift'e mi özgü? Hangi SOLID prensibi?**
Somut tiplerin oluşturulup birbirine bağlandığı tek yer; bizde `AppAssembler`. DIP'in tamamlayıcısıdır: Interactor gibi üst katmanlar `MarketDataProviding` gibi protokollere bağımlı olur, simülatör mü gerçek veri mi verileceğine composition root karar verir. Benzetme: prizler soyutlama, sigorta kutusu composition root. Clean Swift'e özgü değil, genel bir DI kavramı. Orijinal Clean Swift şablonunda her VC kendi `setup()`'ında bağımlılıklarını kendisi kurar; biz bunu `AppAssembler`'a taşıdık.

**`Package.swift`'te neden `.macOS(.v13)` var? `Charts` UIKit kullanırken `swift test` nasıl çalışır?**
`swift test` paketi Mac için derler ve testleri simülatörsüz koşar. `.macOS(.v13)` minimum Mac sürümünü belirtir; `Clock`, `Duration` gibi modern concurrency API'leri macOS 13 ile geldiği için gerekli. Uygulamayı Mac'te yayınlamak anlamına gelmez. UIKit Mac'te olmadığı için view kodu `#if canImport(UIKit)` içinde durur ve Mac'te atlanır. Saf geometri (ölçek, hit-test) bu bloğun dışında olduğu için Mac'te test edilir.

**"Her şey MainActor" varsayılanını neden kapattık? SceneDelegate neden yine de main actor'de?**
`UIResponder` SDK'da `@MainActor`; alt sınıflar izolasyonu miras alır, bu yüzden SceneDelegate ve tüm VC'ler zaten main actor'de. Varsayılanı kapattık çünkü:
1. Paket her zaman nonisolated derleniyor; uygulamada farklı kural olursa tip taşırken izolasyon sessizce değişir.
2. Hangi tipin main thread'de çalıştığını bilinçli seçmek istiyoruz (öğrenme hedefi).
3. Model tiplerinin bile MainActor'e bağlanması "isolated conformance" gibi kafa karıştırıcı hatalar doğurur.

Bedeli: UIKit'ten türemeyen UI tiplerine (`AppAssembler`, Presenter, Interactor) `@MainActor`'ü elle yazmak. Varsayılan MainActor yanlış değil, Apple uygulamalar için öneriyor; biz tutarlılık ve öğrenme için açık yazmayı seçtik.

**Clean Swift yüzünden mi kapattık? Interactor/Presenter main'de olmasın mı istedik?**
Hayır. Interactor ve Presenter da `@MainActor` olacak: VIP döngüsü UI'ı besleyen bir zincir, main'de olması en basit ve güvenli seçim. Ağır işler (fiyat üretimi, JSON, dosya) paketteki actor'lerde çalışır, Interactor onlardan `await` ile sonuç ister. Uygulama tarafında sonuç neredeyse aynı; fark, izolasyonun proje ayarında saklı olması yerine tipin üstünde yazılı olması. Önceki projede de ayar kapalıydı ve `@MainActor` ViewModel'lere elle yazılmıştı; Xcode 26 şablonu bu ayarı varsayılan açtığı için bu sefer bilerek kapattık.

## Phase 1 — Domain

**TDD nedir?**
Önce test, sonra kod. Döngü: 🔴 testi yaz ve başarısız olduğunu gör → 🟢 geçirecek en basit kodu yaz → 🔵 testler yeşilken kodu temizle. Kırmızıyı görmek testin gerçekten bir şey kontrol ettiğini kanıtlar.

**Para için neden `Double` değil `Decimal`?**
`Double` ikili kesir tutar; `0.1 + 0.2` tam `0.3` etmez. `Decimal` ondalık tabanda tutar, kuruş kaybı olmaz. Tuzak: `let d: Decimal = 0.1` önce Double'dan geçer; string'den kurmak güvenli.

**OCP: `Portfolio`'ya `if order.type == .market ... else if .limit ...` yazsaydık ne kaybederdik?**
Her yeni emir tipinde çalışan ve test edilmiş `Portfolio`'yu açıp değiştirmek gerekirdi; `Portfolio` her emir tipinin fiyat kuralını da bilmek zorunda kalırdı (SRP ihlali). Bunun yerine `Portfolio` fiyatı `OrderType` protokolüne soruyor. Yeni emir tipi = yeni bir dosya, `Portfolio` değişmez. "Genişlemeye açık, değişime kapalı."

## Phase 2 — Market simulator

**`MarketSimulator`'ı `actor` yerine `class` yapsaydık Swift 6 ne derdi?**
Class'taki değişen durum (`var prices`) birden fazla yerden (fiyat döngüsü, ekranlar, debug menüsü) aynı anda erişilince data race oluşur. Swift 6 bunu çalışma anında değil derleme anında yakalar: `MarketDataProviding` `Sendable` istiyor, değişen alanları olan class `Sendable` olamaz, kod derlenmez. Alternatifler: kilit + `@unchecked Sendable` (güvenliği derleyici değil biz garanti ederiz) ya da `@MainActor class` (hesaplar main thread'e biner). Actor erişimleri sıraya koyar; bedeli dışarıdan her çağrının `await` olması.

**Testte neden saniyelerce beklemiyoruz?**
Bekleme davranışı (`sleep`) ve saat (`now`) dışarıdan closure olarak veriliyor (DI). Uygulamada gerçek `Task.sleep`, testte hiç beklemeyen bir closure. Testler ayrıca `tick()`'i doğrudan çağırıyor. Aynı seed aynı fiyat yolunu verdiği için sonuçlar tekrarlanabilir.

## Phase 3 — Watchlist (ilk VIP sahnesi)

**VIP döngüsü nedir?**
Tek yönlü bir halka: VC → Interactor → Presenter → VC. VC gösterir ve olayları iletir; Interactor karar verir (Worker'dan veri alır, başarı/hata); Presenter biçimlendirir. Kimse geri dönüp diğerine soru sormaz. VIPER'dan farkı: orada Presenter merkezdir ve akış çift yönlüdür; VIP'te merkez yok, veri halka gibi döner. Router ekran geçişlerini ve DataStore üzerinden veri taşımayı üstlenir.

**Interactor neden doğrudan VC'yi değil Presenter'ı çağırır?**
Formatlama ayrı bir sorumluluk (SRP). Interactor ham veri (`Instrument`, `Money`) tutar; ekran string ve renk kararı ister. Interactor formatlasaydı iş kuralı ve görünüm karışırdı; VC formatlasaydı hesap UIKit'e girer ve test edilemezdi. Presenter araya girince iş kuralı ve görünüm bağımsız değişir, ikisi de UIKit olmadan test edilir.

**Presenter neden UIKit bilmez?**
Presenter rengi `UIColor.systemGreen` olarak değil `.up` olarak verir. Böylece formatlama ekran açmadan test edilir (`row.trend == .up`) ve görünüm kararı (hangi yeşil?) View'da kalır; tema değişince Presenter'a dokunulmaz. Presenter "ne", View "nasıl" gösterileceğine karar verir.

**Skeleton (yükleniyor) durumu VIP'te nasıl modellenir?**
Yükleniyor durumu da bir ViewModel: Interactor veri istemeden önce `presentLoading()` çağırır, Presenter placeholder öğeler üretir, hücre bunları `ShimmerView` (CAGradientLayer animasyonu) ile çizer. VC kendi kafasına göre spinner göstermez; davranış Presenter testinde UI'sız doğrulanır.

**Decorator ile OCP**
`DelayedWatchlistWorker` gerçek Worker'ı sarar ve isteği geciktirir (yavaş ağ taklidi). Ne Worker ne Interactor değişti; davranış sarmalayarak genişletildi.

**Diffable'da kimlik olarak neden satırın tamamı değil hisse kodu?**
Diffable öğeleri kimlikleriyle takip eder. Kimlik satırın tamamı olsaydı her fiyat değişimi yeni bir kimlik demek olurdu: "sil + ekle", hücre yeniden yaratılır, titreme olur. Kimlik = hisse kodu olunca fiyat değişimi aynı öğenin güncellenmesidir; `reconfigureItems` hücreyi yeniden yaratmadan içeriğini değiştirir (`reloadItems`'tan ucuz).

**Canlı akış ve yaşam döngüsü**
Interactor `for await` ile `AsyncStream`'i dinler. VC akışı `viewWillAppear`'da bir Task ile başlatır, `viewDidDisappear`'da iptal eder; iptal akışı bitirir ve abonelik temizlenir.

## Phase 4 — Sparkline

**`draw(_:)` yerine neden `CAShapeLayer`?**
`draw(_:)` her değişimde tüm view'ı CPU'da yeniden boyar. `CAShapeLayer`'a sadece yeni bir `path` verilir, boyamayı Core Animation (GPU) yapar. Katmanlar bir kez kurulur; hücre reuse'ta ve saniyede bir güncellemede sadece yol değişir. Dolgu: `CAGradientLayer` + çizginin altındaki alanı gösteren bir maske katmanı.

**Çizim matematiği neden ayrı bir dosyada?**
`SparklineGeometry` UIKit bilmez (sadece CoreGraphics), bu yüzden macOS'ta simülatörsüz test edilir: en yüksek değer üstte mi, noktalar eşit aralıklı mı, düz seri ortada mı. View sadece bu noktaları birleştirir. Zor kısım test edilir, view ince kalır.

**`#available` / `@available` ne işe yarar?**
Hedef iOS 16 ama iOS 17'de yeni API var (`registerForTraitChanges`). `if #available(iOS 17, *)` çalışma anında sürümü kontrol eder; yeni API sadece destekleyen cihazda çağrılır, iOS 16'da eski yöntem (`traitCollectionDidChange`) çalışır. `@available` ise bir tipi/fonksiyonu sürüme bağlar.

**CALayer renkleri neden elle güncellenir?**
Katmanlar `CGColor` kullanır; `CGColor` dinamik değildir, açık/koyu mod değişince kendiliğinden güncellenmez. `UIColor` saklanır, mod değişince `resolvedColor(with:)` ile yeniden çözülür.

## Phase 5 — Hisse detayı + çizgi grafik

**Clean Swift'te ekranlar arası veri nasıl taşınır?**
VC sadece "bu hisse seçildi" der: `router.routeToStockDetail(symbol:)`. Router iki adım yapar: (1) DataPassing: kaynak sahnenin DataStore'undan (Watchlist Interactor) okur, hedef sahnenin DataStore'una (Detail Interactor) yazar; (2) Navigation: ekranı push eder. Router hedef sahneyi kendisi kurmaz, composition root'tan bir fabrika closure'ı ile alır (DIP); testte fabrika sahte bir DataStore döner.

**`draw(_:)` mı `CAShapeLayer` mı? İkisi birden.**
Nadiren değişen arka plan (ızgara) `draw(_:)` ile Core Graphics'te çizilir; UIKit açık/koyu mod değişince `draw` olan view'ı kendisi yeniden çizer. Her saniye değişen fiyat çizgisi `CAShapeLayer`; sadece path güncellenir. Aralık değişiminde `strokeEnd` 0 → 1 animasyonu çizgiyi "çizerek" getirir.

**Watchlist VC doğrudan `detailVC.instrument = ...` deseydi ne kaybederdik?**
VC hedef ekranın iç yapısını bilmek zorunda kalırdı (sıkı bağımlılık; detay değişince Watchlist de değişir). Veri bulma + ekran kurma + geçiş VC'ye yüklenirdi (SRP ihlali). Router'da olunca geçiş mantığı tek yerde durur ve sahte bir hedef DataStore ile UI'sız test edilir.

**Reentrancy: hızlı aralık değişiminde eski sonuç neden ekranı ezmez?**
`await` noktasında başka işler araya girebilir. Kullanıcı 1Y'ye basıp hemen 1M'ye geçerse, 1Y'nin geç gelen cevabı 1M'yi ezebilirdi. Interactor `await` sonrası "istenen aralık hâlâ güncel aralık mı?" diye kontrol eder; değilse sonucu atar.

## Phase 6 — Mum grafik + crosshair

**Neden `ChartView` içine `if style == .candle` yazmadık da ayrı renderer yazdık? (OCP)**
`if`'li yaklaşımda her yeni grafik tipi (alan, OHLC çubuk…) çalışan `ChartView`'ı açıp değiştirmeyi gerektirirdi; tüm tiplerin çizim kodu tek dosyada büyürdü (SRP ihlali). `ChartView` sadece `ChartRenderer` protokolünü bilir: ızgara, ölçek, crosshair ortak; "nasıl çizilir" renderer'da. Yeni tip = yeni bir dosya, `ChartView` değişmez. Renderer'lar UIKit değil QuartzCore kullandığı için macOS'ta test edilir.

**Parmağın altındaki nokta neden ikili aramayla bulunur?**
Noktalar soldan sağa sıralı. Tek tek gezmek O(n); her adımda aralığı ikiye bölmek O(log n). ~250 nokta için her parmak hareketinde ~8 karşılaştırma.

**Crosshair VIP'te nasıl akar?**
Grafik sadece "şu indeks seçildi" der (UI olayı). VC bunu Interactor'a iletir (`selectPoint`), Interactor seçili mumu ve aralık başlangıcını Presenter'a verir, Presenter fiyat/tarih/değişimi formatlar. Formatlama yine UIKit'siz test edilir.

**Mum grafikte neden yüzlerce katman değil 4 katman?**
Her mum için ayrı katman = yüzlerce CALayer, her biri ayrı bellek ve çizim maliyeti. Yükselen/düşen gövdeler ve fitiller için birer `CAShapeLayer` (toplam 4); her biri tüm mumları tek path'te çizer.

## Phase 7 — Al/Sat

**Paylaşılan portföy neden actor? (`PortfolioStore`)**
Al/sat, detay ve (ileride) portföy ekranı aynı hesabı okur/yazar. Actor erişimleri sıraya koyar: 100 alım emri aynı anda gelse ve nakit 50'sine yetse, tam 50'si başarılı olur, nakit asla eksiye düşmez (testte kanıtlı). Kurallar `Portfolio` struct'ında; actor sadece "tek doğru kopya"yı tutar. Değişiklikler `changes()` akışıyla yayınlanır; detay ekranı bu sayede alımdan hemen sonra "Sell" düğmesini ve pozisyon kartını gösterir.

**Form doğrularken kuralı neden tekrar yazmadık?**
Interactor emri portföyün bir KOPYASINDA deneme olarak çalıştırır (`Portfolio` struct = değer tipi, gerçek hesap değişmez). Domain ne derse o: "nakit yetiyor mu" kuralı tek yerde. Interactor'a ayrıca yazsaydık iki kural zamanla ayrışabilirdi.

**Hata → mesaj kimin işi?**
Interactor "ne oldu"yu bilir (`TradingError.insufficientCash`). Presenter "nasıl söylenir"i bilir ("Not enough cash. Available: ₺50,00."). Mesajlar tablo testiyle doğrulanır; dil/ton değişince sadece Presenter değişir.

**İki akışı aynı anda dinlemek: `async let`**
Detay ekranı hem fiyatı hem portföyü dinler. `async let` ikisini paralel başlatır; ekran kapanınca (Task iptali) ikisi birden biter.

## Hata ayıklama dersleri (iOS 26)

**Büyük başlık neden görünmüyordu?**
`UINavigationBarAppearance.configureWithOpaqueBackground()`: iOS 26'nın yeni (liquid glass) navigation bar'ında opak arka plan büyük başlığın üstünü örtüyordu. Teşhis yöntemi: tema ayarını kapat → başlık geliyor mu? Sonra parçaları tek tek dene (önce renk, sonra arka plan). Çözüm: `configureWithTransparentBackground()`; kaydırınca iOS 26'nın kendi bulanık kenar efekti devreye giriyor.

**Detaya geçerken içerik neden zıplıyordu?**
Büyük başlıklı listeden küçük başlıklı ekrana geçerken bar yüksekliği değişir; scroll view'ın otomatik iç boşluk ayarı (contentInsetAdjustment) geçiş bitince gelir → içerik zıplar. Çözüm: `contentInsetAdjustmentBehavior = .never` + scroll view'ı safe area'ya sabitlemek. Ayrıca ekranın ilk karesi boş olmasın diye Router son bilinen fiyatı aktarır, `viewDidLoad`'da senkron gösterilir.

**Aynı ekranda iki farklı "bugün" yüzdesi**
Başlık önceki kapanışa göre, grafik günün ilk mumuna göre hesaplıyordu. Tek tanım: 1D değişimi = önceki kapanışa göre değişim; bir testle sabitlendi.

## Phase 8 — Portföy, geçmiş, kalıcılık

**Domain tiplerini neden doğrudan `Codable` yapmadık? (DTO)**
Diskteki biçim (`PortfolioSnapshot`) ayrı bir tip. Domain depolama biçimini bilmez (SRP); bir alanın adı değişince eski kayıtlar bozulmaz, eşleme tek yerde yapılır. `schemaVersion` sayesinde eski/yeni dosyalar tanınır; daha yeni bir sürümün dosyası yanlış okunmak yerine açıkça reddedilir.

**Para neden JSON'da metin?**
JSON sayıları `Double` üzerinden okunabildiği için `Decimal`'in kuruş hassasiyeti kaybolabilir. "287.55" metni birebir geri gelir. Okurken `en_US_POSIX` locale: Türkçe cihazda ondalık ayırıcı virgül sanılmasın.

**Atomik yazma nedir?**
Önce geçici dosyaya yazılır, sonra tek hamlede eskisinin yerine konur. Yazma sırasında uygulama kapanırsa eski dosya sağlam kalır; yarım/bozuk dosya oluşmaz.

**`PortfolioStore` kaydederken neden `await` etmiyor? (reentrancy)**
Actor içinde `await` edilen noktada başka bir çağrı araya girebilir. Kayıt async olsaydı, iki emir arka arkaya geldiğinde kayıtlar karışık sırada bitebilirdi. Küçük bir JSON için senkron yazma yeterince hızlı ve actor main thread'de değil; bu yüzden repository protokolü bilerek senkron.

**DIP + LSP: dosya deposu ve bellek deposu**
Domain sadece `PortfolioRepository` protokolünü bilir. Uygulamada `FilePortfolioRepository`, testlerde `InMemoryPortfolioRepository`; ikisi birbirinin yerine geçer. Hangisinin kullanılacağına composition root karar verir (`-inMemoryPortfolio` ile UI testleri temiz başlar).

**Tek ekranda farklı düzenli bölümler: compositional layout**
Hesap kartı, pozisyonlar ve geçmiş tek collection view'da; layout her bölüme kendi `NSCollectionLayoutSection`'ını (başlıklı/başlıksız) verir. Satır kümesi aynıysa `reconfigureItems`, değiştiyse animasyonlu `apply`.

## Phase 9 — Gerçek piyasa verisi

**LSP'nin en somut hali: kaynak değişti, ekranlar değişmedi**
`YahooMarketProvider` simülatörle aynı `MarketDataProviding` sözleşmesini uygular. Watchlist, detay, al/sat ve portföy sahnelerinde tek satır değişmedi; sadece composition root hangi sağlayıcının bağlanacağını seçiyor. Farklar sözleşmenin içinde kalıyor: canlı akış push yerine poll, ağ kopunca `feedInterrupted`, halt bilgisi yok.

**Neden Alamofire değil, `HTTPClient` protokolü?**
Tek bir GET isteği. `URLSession` async/await ile yeterli. Protokol sayesinde testte ağa hiç çıkmayan sahte istemci veriliyor (DIP); testler hızlı, kararlı ve internetten bağımsız.

**Codable uç durumları (gerçek API'de neler bozulabilir?)**
Neredeyse her alan opsiyonel; fiyat dizilerinde `null` (işlem olmayan saat), tatilde mum yok ama fiyat var, `regularMarketPrice` eksik olabiliyor (son kapanışa düşülür), hata da aynı zarfta gelir (`chart.error`) ve 404 ile. Her durum için elle yazılmış fixture + test.

**Double → Decimal**
Yahoo fiyatları `Double` (41.720000001). Kuruşa yuvarlayıp tam sayı üzerinden `Decimal`'e çevrilir: kesin para değeri.

**Paralel istek: TaskGroup**
10 hissenin fiyatı/geçmişi aynı anda istenir; biri hata verirse diğerleri yine gelir; sonuçlar karışık sırada döndüğü için indeksle geri sıralanır. Ağ çağrısı actor dışında (`static`) yapılır ki paralel istekler actor'ü sırada bekletmesin.

**Neden tüm hisseler değil?**
Yahoo'da "tüm BIST'i listele" yok; canlı akış poll olduğu için yüzlerce hisse dakikada yüzlerce istek demek (hız sınırı, pil). Gerçek uygulamalardaki çözüm: kullanıcı arar, izleme listesine ekler; sadece listedekiler takip edilir (Phase 9.5).

## Phase 9.5 — Hisse arama + kişisel izleme listesi

**Debounce (async/await ile)**
Kullanıcı "aksa" yazarken her harfte istek atmak yerine: her harfte bekleyen eski aramayı iptal et, yenisini kısa bir beklemeyle (300 ms) başlat. Bekleme sırasında yeni harf gelirse eski görev iptal edilir ve istek hiç gitmez. Bekleme (`sleep`) dışarıdan verildiği için testte kontrol edilebilir.

**Tek doğruluk kaynağı: depo değişir, ekran yayından güncellenir**
Silme/ekleme/sıralama Interactor'da ekranı doğrudan değiştirmez; `WatchlistStore` değişikliği yayınlar, Watchlist Interactor yayını dinleyip yeniler. Arama ekranından yapılan ekleme de aynı yoldan gelir; iki ekran asla çelişmez.

**Liste değişince akışa yeniden abone olmak**
Fiyat akışı belirli hisselere abone. Liste değişince eski akış bırakılır (abonelik sağlayıcıda temizlenir) ve yeni listeyle yeniden abone olunur. Sadece yeni eklenen hissenin fiyatı ve grafiği indirilir.

**Gerçek veride hatalı fiyat kaydı ("bad tick")**
Yahoo'nun gün içi verisinde bir mum gün ortasında dünkü kapanışla geldi; tüm grafiklerde aynı saatte sivri çizgi oluştu. Sağlayıcı, iki komşusundan da %1'den fazla sapıp hemen geri dönen tekil noktaları atıyor. Temizlik veri katmanında (SRP); ekranlar temiz veri görür.

**Auto Layout: boşluğu kim alır?**
Edit modunda kart daralıp genişleyince sparkline'lar kayıyordu. Sebep: boşluğu alabilecek birden fazla aday vardı ve öncelikler belirsizdi. Dersler: (1) Stack view'a verilen hugging önceliği etkisizdir (intrinsic boyutu yok), öncelik içindeki etiketlere verilir. (2) Sağa yaslı (alignment .trailing) bir stack içeriğinden geniş olabilir; bunu engelleyen düşük öncelikli bir "dar ol" kuralı (`width == 0`, `.fittingSizeLevel`) gerekir. Sonuç: boşluk her zaman isim sütununa gider.

## Phase 10 — "Ya alsaydım?"

**Desen tekrar kullanılınca yeni özellik hızlı gelir**
Senaryo deposu (`WhatIfStore` actor + dosya deposu + değişiklik akışı) portföy ve izleme listesiyle birebir aynı desen. Liste ekranı da Watchlist'teki "liste değişince fiyat akışına yeniden abone ol" desenini kullanıyor. Tutarlı mimarinin getirisi: yeni özellik çoğunlukla bilinen parçaların yeni bir birleşimi.

**Hesap Domain'de, kesirli adet bilinçli**
`WhatIfScenario` "o para bugün ne olurdu" sorusunu cevaplar; emir kuralı değil. 100.000 ₺ / 287,50 ₺ = 347,83 adet. Alım fiyatı seçilen günün mumunun açılışı; hafta sonu/tatilse sonraki ilk işlem günü (`WhatIfCalculator.entryIndex`). Son 1 ay günlük, daha eskisi haftalık mumlarla.

**Düzenleme için yeni ekran değil: DataPassing**
Satıra dokununca aynı oluşturucu açılır; liste Router'ı seçilen senaryoyu oluşturucunun DataStore'una (`editing`) yazar. DataStore boşsa "yeni", doluysa "düzenle". Kaydetme aynı kimlikle `update` eder; listede yerinde değişir. İki ayrı ekran yazsaydık zamanla birbirinden farklılaşırlardı.

**Ortak hücre (DRY)**
Portföy ve What If satırları aynı `CardRowCell`'i kullanır; ViewModel → hücre içeriği eşlemesi her sahnenin kendi küçük extension'ında. Auto Layout düzeltmesi tek yerde.

## Phase 11 — Uygulama içi uç durumlar

**Uç durumlar nasıl test edilir? Tetikleyiciyi ekranın değil kaynağın içine koy**
Debug menüsü ekranlara "halt göster" demez; simülatöre `.halt(THYAO)` der. Ekranlar olayı normal fiyat akışından (`MarketUpdate.halted`) alır. Böylece test edilen şey gerçek kod yoludur. Aynı mantıkla Phase 2'de tetikleyiciler Domain sözleşmesinin (`MarketControlling`) parçası yapılmıştı; ISP sayesinde ekranlar bu protokolü görmez.

**Debug menüsü neden VIP sahnesi değil?**
Ürünün parçası değil, composition root'un simülatöre erişimiyle çalışan bir geliştirici aracı. Her şeyi VIP'e sokmak "katman sayısı" olurdu; SOLID'in amacı esneklik.

**Durumu kim söyler, kim gösterir?**
Interactor durumu bilir (`isHalted`, `isFeedInterrupted`), Presenter iki durum aynı anda olursa hangisinin gösterileceğine karar verir (durdurma öncelikli) ve al/sat'ın açık olup olmadığını söyler; VC sadece şeridi gösterir ve düğmeleri kilitler. Öncelik kuralı tablo testiyle sabit.

**Tekrar kullanılabilir durum şeridi**
`StatusBannerView`: metin verince belirir, `nil` verince kaybolur; VoiceOver'a duyurur. Watchlist ve detay aynı bileşeni kullanır.

**Sallama hareketi nereden yakalanır?**
Responder zincirinde kimse işlemezse olay en sonda pencereye gelir; `UIWindow` alt sınıfı (`ShakeWindow`) `motionEnded`'ı yakalar ve composition root'a haber verir.

## Phase 12 — Performans

**Ölç → değiştir → tekrar ölç (gerçek sayılar)**
Yük testi: 120 hisse × saniyede 10 tick = saniyede 1.200 fiyat. Simülatör, Release derleme, 20 sn Time Profiler:
- Önce: saniyede ~1.160 diffable `apply` (her fiyat ayrı), ana thread CPU %57,9.
- Sonra: saniyede ~11 `apply` (her tick tek seferde ~106 satır), ana thread CPU %11,3 → ~5 kat az.
Simülatör sayısı cihaz sayısı değildir; anlamlı olan önce/sonra oranı. Ayrıntı: `docs/PERFORMANCE.md`.

**Toplu güncelleme (batching / coalescing)**
`UpdateCoalescer` güncellemeleri biriktirir, her hissenin sadece son değerini tutar ve bir "zamanlama" anında hepsini tek seferde teslim eder. Zamanlama dışarıdan verilir (DIP): uygulamada ekran karesi (`CADisplayLink`, liste için en fazla 30 kare/sn), testte elle tetiklenen sahte. Böylece 1.200 güncellemenin tek teslime indiği UI olmadan test edilir.

**Neden 30 değil ~11 apply/sn?**
Fiyatlar her 100 ms'de 120'lik bir patlama halinde gelir; her patlama bir kareye toplanır. İki tick arasında uygulanacak yeni bir şey olmadığı için kare boş geçer. Yani toplam iş, veri hızına göre ölçeklenir; ekran yenileme hızına göre değil.

**Offscreen rendering**
`cornerRadius` + `clipsToBounds` içerikli bir katmanda (UILabel) GPU'ya ekstra bir çizim geçişi yaptırır. UILabel arka planını kendi içeriğine çizdiği için maske gerekiyordu; arka planı `layer.backgroundColor`'a verince köşe maskesiz yuvarlanır.

**os_signpost ile ölçüm**
`OSSignposter` aralıkları ("Watchlist apply", "N rows") Instruments'ta zaman çizelgesinde görünür; `xctrace export` ile XML'e alınıp sayılabilir. Ölçüm kodu üretimde neredeyse bedavadır.

## Phase 13 — Cila ve yayın hazırlığı

**Ekran görüntüleri için demo modu**
`-demoData` bellekte hazır bir hesap ve senaryolarla açılır; kayıtlı veriye dokunmaz. Görseller her seferinde aynı ve temiz çıkar; yeniden çekmek tek komut. Durum çubuğu `simctl status_bar override` ile 9:41 / tam pil yapılır.

**Ekran görüntüsü çekerken bulunan hatalar**
- Portföy satırında alt satır kırpılıyordu → "100 × ₺138,90" kısa biçimi.
- Düzenlemede alım fiyatı geçmişten yeniden hesaplanıyordu; liste +%24 derken düzenleme -%1,6 gösterdi. Kaydedilmiş alım fiyatı bir olgudur: sadece hisse ya da tarih değişince yeniden hesaplanır (testle sabit).
Ders: Gerçek veriyle, gerçek ekranda bakmak testlerin kaçırdığını yakalar.

**Erişilebilirlik**
Dynamic Type: tema fontları `UIFontMetrics` ile ölçeklenir; sabit kutulu rozetlerde üst sınır. VoiceOver: grafik "Price chart, 1D: +%0,84 · Today, High…, Low…" diye özetlenir, ipucu crosshair kullanımını anlatır.

**Koyu tema ve açılış ekranı**
`UIUserInterfaceStyle = Dark` sistem seviyesinde (alert ve sheet'ler de tutarlı). Açılış ekranı storyboard yerine Info.plist'te tek renk (`UILaunchScreen`): koyu uygulamada beyaz yanıp sönme yok.

**Lisans ve yayın kararı**
MIT lisansı. Dağıtım TestFlight public link ile; gerçek veri (resmî olmayan uç nokta, BIST veri lisansı) dağıtım derlemesinde kapalı olacak.
