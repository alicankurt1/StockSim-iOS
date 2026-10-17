import Foundation
import Domain

/// Yahoo Finance "chart" uç noktasının yanıtı (sadece kullandığımız alanlar).
///
/// Codable uç durumları:
/// - Neredeyse her alan opsiyonel: piyasa kapalıyken, tatilde ya da yeni listelenmiş
///   hissede alanlar eksik ya da `null` gelebilir.
/// - Fiyat dizilerinde `null` olabilir (o dakikada işlem olmamış) → `[Double?]`.
/// - Hata da 200 dışı bir kodla aynı zarfta gelir: `{"chart":{"result":null,"error":{…}}}`.
struct YahooChartResponse: Decodable {

    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
        let error: APIError?
    }

    struct APIError: Decodable {
        let code: String
        let description: String?
    }

    struct Result: Decodable {
        let meta: Meta
        let timestamp: [TimeInterval]?
        let indicators: Indicators?
    }

    struct Meta: Decodable {
        let symbol: String
        let regularMarketPrice: Double?
        /// Grafiğin başladığı andan önceki kapanış; 1 günlük grafikte = dünkü kapanış.
        let chartPreviousClose: Double?
        let previousClose: Double?
        let regularMarketTime: TimeInterval?
    }

    struct Indicators: Decodable {
        let quote: [Series]?
    }

    struct Series: Decodable {
        let open: [Double?]?
        let high: [Double?]?
        let low: [Double?]?
        let close: [Double?]?
    }
}

// MARK: - Yanıt → Domain

extension YahooChartResponse.Result {

    /// Anlık fiyat. `regularMarketPrice` yoksa serinin son kapanışı kullanılır.
    func quote(for symbol: Symbol) throws -> Quote {
        guard let price = meta.regularMarketPrice ?? lastClose else {
            throw MarketDataError.unavailable("No price for \(symbol)")
        }
        let previousClose = meta.chartPreviousClose ?? meta.previousClose ?? price
        let time = meta.regularMarketTime ?? timestamp?.last ?? 0
        return Quote(
            symbol: symbol,
            price: YahooMoney.money(price),
            previousClose: YahooMoney.money(previousClose),
            timestamp: Date(timeIntervalSince1970: time)
        )
    }

    /// Mumlar. Değerlerinden biri `null` olan satırlar atlanır (işlem olmayan dakika/gün);
    /// tekil hatalı fiyat kayıtları ("bad tick") temizlenir.
    func candles() -> [Candle] {
        guard let times = timestamp, let series = indicators?.quote?.first else { return [] }
        let opens = series.open ?? [], highs = series.high ?? [], lows = series.low ?? [], closes = series.close ?? []

        let parsed: [Candle] = times.indices.compactMap { index in
            guard index < opens.count, index < highs.count, index < lows.count, index < closes.count,
                  let open = opens[index], let high = highs[index], let low = lows[index], let close = closes[index]
            else { return nil }
            return Candle(
                date: Date(timeIntervalSince1970: times[index]),
                open: YahooMoney.money(open),
                high: YahooMoney.money(high),
                low: YahooMoney.money(low),
                close: YahooMoney.money(close)
            )
        }
        return Self.removingIsolatedSpikes(parsed)
    }

    /// Gerçek veride bazen tek bir mum saçma bir fiyatla gelir (ör. gün ortasında dünkü kapanış).
    /// Kural: kapanışı iki komşusundan da `threshold`'dan fazla sapan, ama komşuları birbirine
    /// yakın olan (fiyat hemen eski yerine dönmüş) TEKİL nokta hatalı sayılır ve atılır.
    /// Gerçek sert hareketler ardışık mumlarda sürdüğü için bu kurala takılmaz.
    static func removingIsolatedSpikes(_ candles: [Candle], threshold: Decimal = Decimal(string: "0.01")!) -> [Candle] {
        guard candles.count >= 3 else { return candles }
        func distance(_ a: Money, _ b: Money) -> Decimal {
            let base = b.amount
            guard base > 0 else { return 0 }
            let difference = a.amount - b.amount
            return (difference < 0 ? -difference : difference) / base
        }
        var cleaned: [Candle] = [candles[0]]
        for index in 1..<(candles.count - 1) {
            let previous = candles[index - 1].close, current = candles[index].close, next = candles[index + 1].close
            let isSpike = distance(current, previous) > threshold
                && distance(current, next) > threshold
                && distance(previous, next) < threshold / 2
            if !isSpike { cleaned.append(candles[index]) }
        }
        cleaned.append(candles[candles.count - 1])
        return cleaned
    }

    private var lastClose: Double? {
        indicators?.quote?.first?.close?.compactMap { $0 }.last
    }
}

enum YahooMoney {
    /// Yahoo fiyatları `Double` verir (ör. 41.720000001). Kuruşa yuvarlayıp tam sayı
    /// üzerinden `Decimal`'e çeviriyoruz: Double → Decimal hassasiyet kaybı olmaz.
    static func money(_ value: Double) -> Money {
        Money(Decimal(Int64((value * 100).rounded())) / 100)
    }
}
