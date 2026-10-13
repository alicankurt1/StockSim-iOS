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
