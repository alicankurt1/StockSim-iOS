# Öğrenme Notları

Her fazın sonunda sorulan soruların düzeltilmiş cevapları. Amaç: kavramları kendi cümlelerimle anlatabilmek.

## Proje başı kararları

**Neden Alamofire yok?**
Tek bir GET isteği atıyoruz. `URLSession` async/await ile bunu birkaç satırda yapıyor. Alamofire'ın güçlü olduğu interceptor, retry, multipart gibi özelliklere ihtiyacımız yok. Küçük bir `HTTPClient` protokolü yazmak hem bağımlılığı ortadan kaldırıyor hem de DIP'i ve sahte client'la test etmeyi doğrudan gösteriyor.

**Neden gerçek veri için Yahoo, neden doğrudan BIST değil?**
BIST veriyi ücretsiz API olarak sunmuyor. Resmi veri lisanslı dağıtıcılar üzerinden ve ücretli. Kapanış fiyatı her kaynakta aynı, risk verinin doğruluğunda değil endpoint'in değişmesinde. Bu yüzden veri kaynağı `MarketDataProviding` protokolünün arkasında. Kaynak değişirse sadece yeni bir provider yazılıyor (OCP + DIP).

**Neden iOS 16?**
Geniş cihaz desteği için. Daha yeni API'ler (`registerForTraitChanges`, UIKit `#Preview`) `@available` ile kullanılacak.

## Phase 0

_(faz sonunda doldurulacak)_
