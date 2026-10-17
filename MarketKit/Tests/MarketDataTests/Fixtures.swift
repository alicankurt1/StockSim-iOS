import Foundation
@testable import MarketData

/// Yahoo yanıtlarının elle yazılmış kopyaları: gerçek biçimle aynı, değerler uydurma.
/// Testler asla ağa çıkmaz; her uç durum için ayrı bir fixture var.
enum Fixture {

    /// Normal gün: 3 saatlik mum, ortasında işlem olmayan bir saat (`null`).
    static let intraday = """
    {"chart":{"result":[{
      "meta":{"symbol":"THYAO.IS","currency":"TRY","regularMarketPrice":273.5,
              "chartPreviousClose":276.75,"previousClose":276.75,"regularMarketTime":1792163398},
      "timestamp":[1792132200,1792135800,1792139400],
      "indicators":{"quote":[{
        "open":[273.0,null,273.0],
        "high":[274.5,null,274.5],
        "low":[271.25,null,271.25],
        "close":[274.25,null,272.0],
        "volume":[0,null,3356351]
      }]}
    }],"error":null}}
    """

    /// Tatil / piyasa kapalı: zaman ve fiyat dizileri yok, sadece meta.
    static let holiday = """
    {"chart":{"result":[{
      "meta":{"symbol":"THYAO.IS","regularMarketPrice":270.0,"chartPreviousClose":268.0,"regularMarketTime":1792163398},
      "indicators":{"quote":[{}]}
    }],"error":null}}
    """

    /// `regularMarketPrice` yok: son kapanış kullanılmalı. Fiyatta Double gürültüsü var.
    static let missingMarketPrice = """
    {"chart":{"result":[{
      "meta":{"symbol":"SISE.IS","chartPreviousClose":41.5},
      "timestamp":[1792132200,1792135800],
      "indicators":{"quote":[{"open":[41.5,41.6],"high":[41.8,41.9],"low":[41.4,41.5],"close":[41.6,41.720000001]}]}
    }],"error":null}}
    """

    /// Bilinmeyen hisse: 404 + hata zarfı.
    static let notFound = """
    {"chart":{"result":null,"error":{"code":"Not Found","description":"No data found, symbol may be delisted"}}}
    """

    /// Arama: farklı borsalar ve bir fon karışık; sadece ".IS" hisse senetleri alınmalı.
    static let search = """
    {"quotes":[
      {"symbol":"AHG","shortname":"Akso Health Group","quoteType":"EQUITY"},
      {"symbol":"AKSA.IS","shortname":"AKSA","longname":"Aksa Akrilik Kimya Sanayii A.S.","quoteType":"EQUITY"},
      {"symbol":"0P0001A2PM.IS","shortname":"Some Fund","quoteType":"MUTUALFUND"},
      {"symbol":"AKSEN.IS","shortname":"AKSA ENERJI","quoteType":"EQUITY"}
    ]}
    """

    static func data(_ json: String) -> Data { Data(json.utf8) }
}

/// Ağa çıkmayan sahte istemci: URL'deki hisse koduna göre hazır yanıt döner ve istekleri kaydeder.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {

    enum Reply {
        case json(String, status: Int = 200)
        case failure(URLError.Code)
    }

    private let lock = NSLock()
    private var replies: [String: [Reply]] = [:]
    private var fallback: Reply
    private(set) var requestedURLs: [URL] = []

    init(fallback: Reply = .json(Fixture.intraday)) {
        self.fallback = fallback
    }

    /// Bu hisse için sırayla dönecek yanıtlar; bitince `fallback`.
    func enqueue(_ yahooSymbol: String, _ replies: Reply...) {
        lock.withLock { self.replies[yahooSymbol, default: []].append(contentsOf: replies) }
    }

    func setFallback(_ reply: Reply) {
        lock.withLock { fallback = reply }
    }

    var requestCount: Int { lock.withLock { requestedURLs.count } }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        let reply: Reply = lock.withLock {
            requestedURLs.append(url)
            // Arama isteğinde anahtar "search", grafik isteğinde hisse kodu ("THYAO.IS").
            let symbol = url.lastPathComponent
            if var queue = replies[symbol], !queue.isEmpty {
                let next = queue.removeFirst()
                replies[symbol] = queue
                return next
            }
            return fallback
        }
        switch reply {
        case let .json(json, status):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Fixture.data(json), response)
        case let .failure(code):
            throw URLError(code)
        }
    }
}
