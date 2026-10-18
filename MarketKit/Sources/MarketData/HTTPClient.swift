// Sadece Debug derlemesi (Package.swift → REAL_DATA).
#if REAL_DATA
import Foundation

/// Ağ isteği atan şey. Sağlayıcı sadece bu protokolü bilir (DIP):
/// uygulamada `URLSession`, testte ağa hiç çıkmayan sahte bir istemci.
///
/// Alamofire yerine 10 satırlık bir protokol: tek bir GET isteği atıyoruz ve
/// test edilebilirlik için ihtiyacımız olan tek şey "yerine sahtesini verebilmek".
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
#endif
