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
