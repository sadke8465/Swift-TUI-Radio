import Foundation

// MARK: - IP Geolocation
// Uses ip-api.com — free tier, no auth required, 45 requests/minute.
// Endpoint: http://ip-api.com/json/?fields=status,message,country,countryCode,city

// MARK: - Response Model

struct IPAPIResponse: Codable {
    let status: String
    let country: String?
    let countryCode: String?
    let city: String?
    let message: String?    // present only on "fail" responses
}

// MARK: - Errors

enum GeolocationError: LocalizedError {
    case httpError(Int)
    case apiFailure(String)
    case missingCountryCode

    var errorDescription: String? {
        switch self {
        case .httpError(let code):      return "Geolocation HTTP error \(code)"
        case .apiFailure(let msg):      return "Geolocation API failure: \(msg)"
        case .missingCountryCode:       return "Geolocation response missing countryCode"
        }
    }
}

// MARK: - Service

actor GeolocationService {
    static let shared = GeolocationService()

    private let endpointURL = URL(string: "http://ip-api.com/json/?fields=status,message,country,countryCode,city")!

    /// Detect the user's ISO 3166-1 alpha-2 country code via IP geolocation.
    /// Falls back to "US" on any error.
    func fetchCountryCode() async -> String {
        print("[DEBUG][GeoLocation] Starting IP geolocation request...")
        print("[DEBUG][GeoLocation] URL: \(endpointURL.absoluteString)")

        do {
            var request = URLRequest(url: endpointURL)
            request.setValue("Swift-TUI-Radio/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("[DEBUG][GeoLocation] HTTP status: \(httpResponse.statusCode)")
                guard httpResponse.statusCode == 200 else {
                    throw GeolocationError.httpError(httpResponse.statusCode)
                }
            }

            print("[DEBUG][GeoLocation] Received \(data.count) bytes")

            if let rawJSON = String(data: data.prefix(300), encoding: .utf8) {
                print("[DEBUG][GeoLocation] Raw response: \(rawJSON)")
            }

            let decoded = try JSONDecoder().decode(IPAPIResponse.self, from: data)
            print("[DEBUG][GeoLocation] Decoded — status: \(decoded.status), country: \(decoded.country ?? "nil"), countryCode: \(decoded.countryCode ?? "nil"), city: \(decoded.city ?? "nil")")

            if decoded.status == "fail" {
                let msg = decoded.message ?? "unknown error"
                print("[DEBUG][GeoLocation] API reported failure: \(msg)")
                throw GeolocationError.apiFailure(msg)
            }

            guard let code = decoded.countryCode, !code.isEmpty else {
                print("[DEBUG][GeoLocation] countryCode missing or empty in response")
                throw GeolocationError.missingCountryCode
            }

            let upperCode = code.uppercased()
            print("[DEBUG][GeoLocation] Success — detected country: \(decoded.country ?? "?") (\(upperCode))")
            return upperCode

        } catch {
            print("[DEBUG][GeoLocation] Error: \(error.localizedDescription) — falling back to US")
            return "US"
        }
    }
}
