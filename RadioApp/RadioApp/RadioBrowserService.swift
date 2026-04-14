import Foundation

// MARK: - Radio Browser API
// Free, open-source, no authentication required.
// Docs: https://api.radio-browser.info
// Server: https://de1.api.radio-browser.info

// MARK: - Raw API Response Model

struct RBStation: Codable {
    let stationuuid: String
    let name: String
    let url_resolved: String
    let country: String
    let countrycode: String
    let tags: String
    let codec: String
    let bitrate: Int
    let votes: Int
    let lastcheckok: Int
    let favicon: String?
    let homepage: String?
}

// MARK: - Frequency Parser

struct FrequencyParser {
    // FM broadcast band (ITU Region 1/2/3): 87.5 – 108.0 MHz
    private static let fmMin: Double = 87.5
    private static let fmMax: Double = 108.0

    // Matches 2–3 digit whole part + 1–2 decimal digits, optional FM/MHz suffix.
    // Anchored with \b so "1234.5" won't accidentally match.
    private static let pattern = #"\b(\d{2,3}\.\d{1,2})\s*(?:FM|MHz|mhz|fm)?\b"#

    /// Parse an FM frequency from a station name and/or tags string.
    /// Returns e.g. "98.7 FM" or "Online" if no valid FM frequency is found.
    static func parse(name: String, tags: String) -> String {
        print("[DEBUG][FrequencyParser] Parsing — name: \"\(name)\" | tags: \"\(tags)\"")

        if let freq = extract(from: name, source: "name") {
            let result = "\(freq) FM"
            print("[DEBUG][FrequencyParser] Found in name → \(result)")
            return result
        }

        if !tags.isEmpty, let freq = extract(from: tags, source: "tags") {
            let result = "\(freq) FM"
            print("[DEBUG][FrequencyParser] Found in tags → \(result)")
            return result
        }

        print("[DEBUG][FrequencyParser] No FM frequency found → Online")
        return "Online"
    }

    private static func extract(from text: String, source: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            print("[DEBUG][FrequencyParser] Regex compilation failed for source: \(source)")
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        print("[DEBUG][FrequencyParser] \(matches.count) regex match(es) in \(source): \"\(text)\"")

        for match in matches {
            guard let swiftRange = Range(match.range(at: 1), in: text) else {
                print("[DEBUG][FrequencyParser] Could not convert NSRange to Swift Range")
                continue
            }
            let freqStr = String(text[swiftRange])
            guard let freq = Double(freqStr) else {
                print("[DEBUG][FrequencyParser] Could not parse Double from: \(freqStr)")
                continue
            }

            if freq >= fmMin && freq <= fmMax {
                // Strip unnecessary trailing ".0" (e.g. 98.0 → "98.0" stays, not "98")
                print("[DEBUG][FrequencyParser] Valid FM frequency in \(source): \(freqStr)")
                return freqStr
            } else {
                print("[DEBUG][FrequencyParser] Out of FM band (\(fmMin)–\(fmMax)): \(freqStr)")
            }
        }
        return nil
    }
}

// MARK: - Radio Browser Errors

enum RadioBrowserError: LocalizedError {
    case invalidURL(String)
    case httpError(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):  return "Invalid Radio Browser URL: \(url)"
        case .httpError(let code):  return "Radio Browser HTTP error \(code)"
        case .emptyResponse:        return "Radio Browser returned empty response"
        }
    }
}

// MARK: - Service

actor RadioBrowserService {
    static let shared = RadioBrowserService()

    private let baseURL = "https://de1.api.radio-browser.info/json"

    // MARK: Public API

    /// Fetch top stations from the user's country (for the "All Stations" tab).
    func fetchStationsByCountry(_ countryCode: String, limit: Int = 100) async throws -> [Station] {
        print("[DEBUG][RadioBrowser] fetchStationsByCountry — countryCode: \(countryCode), limit: \(limit)")

        var components = URLComponents(string: "\(baseURL)/stations/search")!
        components.queryItems = [
            URLQueryItem(name: "countrycode", value: countryCode),
            URLQueryItem(name: "limit",       value: "\(limit)"),
            URLQueryItem(name: "hidebroken",  value: "true"),
            URLQueryItem(name: "order",       value: "votes"),
            URLQueryItem(name: "reverse",     value: "true"),
        ]

        guard let url = components.url else {
            print("[DEBUG][RadioBrowser] Failed to build URL for countrycode=\(countryCode)")
            throw RadioBrowserError.invalidURL("\(baseURL)/stations/search?countrycode=\(countryCode)")
        }

        return try await fetchAndDecode(url: url, assignGenre: .all)
    }

    /// Fetch top 20 stations globally for a given tag (for genre tabs).
    func fetchStationsByTag(_ tag: String, limit: Int = 20) async throws -> [Station] {
        print("[DEBUG][RadioBrowser] fetchStationsByTag — tag: \(tag), limit: \(limit)")

        var components = URLComponents(string: "\(baseURL)/stations/search")!
        components.queryItems = [
            URLQueryItem(name: "tag",        value: tag),
            URLQueryItem(name: "limit",      value: "\(limit)"),
            URLQueryItem(name: "hidebroken", value: "true"),
            URLQueryItem(name: "order",      value: "votes"),
            URLQueryItem(name: "reverse",    value: "true"),
        ]

        guard let url = components.url else {
            print("[DEBUG][RadioBrowser] Failed to build URL for tag=\(tag)")
            throw RadioBrowserError.invalidURL("\(baseURL)/stations/search?tag=\(tag)")
        }

        let genre = genreFromTag(tag)
        print("[DEBUG][RadioBrowser] Tag '\(tag)' mapped to genre: \(genre.rawValue)")
        return try await fetchAndDecode(url: url, assignGenre: genre)
    }

    // MARK: Private Helpers

    private func fetchAndDecode(url: URL, assignGenre: Genre) async throws -> [Station] {
        print("[DEBUG][RadioBrowser] GET \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue(
            "Swift-TUI-Radio/1.0 (github.com/sadke8465/swift-tui-radio)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[DEBUG][RadioBrowser] Network error for \(url.lastPathComponent): \(error.localizedDescription)")
            throw error
        }

        if let httpResponse = response as? HTTPURLResponse {
            print("[DEBUG][RadioBrowser] HTTP \(httpResponse.statusCode) — \(url.lastPathComponent)")
            guard httpResponse.statusCode == 200 else {
                print("[DEBUG][RadioBrowser] Non-200 status: \(httpResponse.statusCode)")
                throw RadioBrowserError.httpError(httpResponse.statusCode)
            }
        }

        print("[DEBUG][RadioBrowser] Received \(data.count) bytes for genre: \(assignGenre.rawValue)")

        if data.isEmpty {
            print("[DEBUG][RadioBrowser] Empty response body")
            throw RadioBrowserError.emptyResponse
        }

        let rawStations: [RBStation]
        do {
            rawStations = try JSONDecoder().decode([RBStation].self, from: data)
        } catch {
            print("[DEBUG][RadioBrowser] JSON decode error: \(error)")
            if let preview = String(data: data.prefix(500), encoding: .utf8) {
                print("[DEBUG][RadioBrowser] Response preview (500 chars): \(preview)")
            }
            throw error
        }

        print("[DEBUG][RadioBrowser] Decoded \(rawStations.count) raw stations for '\(assignGenre.rawValue)'")

        var stations: [Station] = []
        var validStreamCount = 0

        for (i, raw) in rawStations.enumerated() {
            let freq = FrequencyParser.parse(name: raw.name, tags: raw.tags)

            // Prefer countrycode field; fall back to first 2 chars of country name
            let rawCode = raw.countrycode.trimmingCharacters(in: .whitespaces)
            let countryCode: String
            if !rawCode.isEmpty {
                countryCode = rawCode.uppercased()
            } else {
                let fallback = String(raw.country.prefix(2)).uppercased()
                print("[DEBUG][RadioBrowser] Station[\(i)] missing countrycode, using fallback: \(fallback)")
                countryCode = fallback
            }

            let hasStream = !raw.url_resolved.trimmingCharacters(in: .whitespaces).isEmpty
            if hasStream { validStreamCount += 1 }

            print("[DEBUG][RadioBrowser] [\(i+1)/\(rawStations.count)] \"\(raw.name)\" | \(countryCode) | freq:\(freq) | votes:\(raw.votes) | codec:\(raw.codec) | bitrate:\(raw.bitrate) | stream:\(hasStream ? "✓" : "✗")")

            let station = Station(
                id:        raw.stationuuid,
                name:      raw.name,
                frequency: freq,
                country:   countryCode,
                genre:     assignGenre,
                streamURL: raw.url_resolved.trimmingCharacters(in: .whitespaces),
                votes:     raw.votes,
                rawTags:   raw.tags
            )
            stations.append(station)
        }

        print("[DEBUG][RadioBrowser] Finished '\(assignGenre.rawValue)': \(validStreamCount)/\(stations.count) stations have stream URLs")
        return stations
    }

    private func genreFromTag(_ tag: String) -> Genre {
        switch tag.lowercased() {
        case "news", "talk", "information":  return .news
        case "jazz", "blues", "soul":        return .jazz
        case "rock", "metal", "alternative": return .rock
        default:
            print("[DEBUG][RadioBrowser] Unknown tag '\(tag)' — defaulting to .all")
            return .all
        }
    }
}
