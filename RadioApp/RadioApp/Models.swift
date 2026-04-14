import SwiftUI
import Combine
import AVFoundation

// MARK: - Data Types

enum Genre: String, CaseIterable {
    case all  = "All Stations"
    case news = "News"
    case jazz = "Jazz"
    case rock = "Rock"
}

enum AppView {
    case stations, nowPlaying
}

struct Station: Identifiable, Equatable {
    let id: String          // stationuuid from Radio Browser API
    let name: String
    let frequency: String   // e.g. "98.7 FM" or "Online"
    let country: String     // ISO 3166-1 alpha-2, e.g. "US"
    let genre: Genre
    let streamURL: String   // url_resolved from Radio Browser API
    let votes: Int
    let rawTags: String     // raw comma-separated tags from API
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var currentView: AppView = .stations
    @Published var selectedID: String = ""
    @Published var playingID: String? = nil
    @Published var favorites: Set<String> = []
    @Published var selectedGenreIndex: Int = 0
    @Published var slideDirection: SlideDirection = .right
    @Published var isLoading: Bool = false
    @Published var hasFirstLoaded: Bool = false
    @Published var isTransitioning: Bool = false

    // API-sourced data
    @Published var stations: [Station] = []
    @Published var userCountryCode: String = ""
    @Published var loadError: String? = nil

    enum SlideDirection { case left, right }

    // MARK: - Audio Player

    private var player: AVPlayer?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        $playingID
            .sink { [weak self] newID in
                guard let self = self else { return }
                self.player?.pause()
                self.player = nil

                guard let id = newID,
                      let station = self.stations.first(where: { $0.id == id }),
                      let url = URL(string: station.streamURL) else { return }

                let newPlayer = AVPlayer(url: url)
                newPlayer.play()
                self.player = newPlayer
                print("[DEBUG][Audio] Playing: \(station.name) — \(station.streamURL)")
            }
            .store(in: &cancellables)
    }

    var selectedGenre: Genre { Genre.allCases[selectedGenreIndex] }

    // All Stations tab → country-filtered stations
    // Genre tabs → globally-ranked stations for that genre
    var filteredStations: [Station] {
        selectedGenre == .all
            ? stations.filter { $0.genre == .all }
            : stations.filter { $0.genre == selectedGenre }
    }

    var selectedStation: Station? { stations.first { $0.id == selectedID } }
    var playingStation: Station? {
        guard let pid = playingID else { return nil }
        return stations.first { $0.id == pid }
    }
    var favoriteStations: [Station] { stations.filter { favorites.contains($0.id) } }

    // MARK: - Data Loading

    @MainActor
    func loadAllData() async {
        print("[DEBUG][AppState] loadAllData() starting")

        isLoading = true
        stations = []
        loadError = nil

        // ── Step 1: IP Geolocation ──────────────────────────────────────────
        print("[DEBUG][AppState] Step 1 — geolocating user...")
        let countryCode = await GeolocationService.shared.fetchCountryCode()
        userCountryCode = countryCode
        print("[DEBUG][AppState] User country code resolved to: \(countryCode)")

        // ── Step 2: Parallel fetches via TaskGroup ──────────────────────────
        print("[DEBUG][AppState] Step 2 — launching parallel fetches: country=\(countryCode), news, jazz, rock")

        var combined: [Station] = []

        await withTaskGroup(of: [Station].self) { group in

            // All Stations: top 100 from user's country
            group.addTask {
                do {
                    let result = try await RadioBrowserService.shared.fetchStationsByCountry(countryCode)
                    print("[DEBUG][AppState] ✓ country(\(countryCode)): \(result.count) stations")
                    return result
                } catch {
                    print("[DEBUG][AppState] ✗ country(\(countryCode)) FAILED: \(error.localizedDescription)")
                    return []
                }
            }

            // News: top 20 globally
            group.addTask {
                do {
                    let result = try await RadioBrowserService.shared.fetchStationsByTag("news")
                    print("[DEBUG][AppState] ✓ news: \(result.count) stations")
                    return result
                } catch {
                    print("[DEBUG][AppState] ✗ news FAILED: \(error.localizedDescription)")
                    return []
                }
            }

            // Jazz: top 20 globally
            group.addTask {
                do {
                    let result = try await RadioBrowserService.shared.fetchStationsByTag("jazz")
                    print("[DEBUG][AppState] ✓ jazz: \(result.count) stations")
                    return result
                } catch {
                    print("[DEBUG][AppState] ✗ jazz FAILED: \(error.localizedDescription)")
                    return []
                }
            }

            // Rock: top 20 globally
            group.addTask {
                do {
                    let result = try await RadioBrowserService.shared.fetchStationsByTag("rock")
                    print("[DEBUG][AppState] ✓ rock: \(result.count) stations")
                    return result
                } catch {
                    print("[DEBUG][AppState] ✗ rock FAILED: \(error.localizedDescription)")
                    return []
                }
            }

            for await batch in group {
                combined.append(contentsOf: batch)
            }
        }

        // ── Step 3: Publish results ─────────────────────────────────────────
        let countryCount = combined.filter { $0.genre == .all  }.count
        let newsCount    = combined.filter { $0.genre == .news }.count
        let jazzCount    = combined.filter { $0.genre == .jazz }.count
        let rockCount    = combined.filter { $0.genre == .rock }.count
        print("[DEBUG][AppState] Fetch complete — total:\(combined.count)  country:\(countryCount)  news:\(newsCount)  jazz:\(jazzCount)  rock:\(rockCount)")

        if combined.isEmpty {
            print("[DEBUG][AppState] WARNING: No stations loaded — all fetches may have failed")
            loadError = "Could not load stations. Check your internet connection."
        }

        stations = combined
        isLoading = false
        hasFirstLoaded = true

        // Snap selection to first station in current view
        clampSelectionToFilter()
        print("[DEBUG][AppState] loadAllData() complete — selectedID: \(selectedID)")
    }

    // MARK: - Keyboard Actions

    func moveDown() {
        let list = filteredStations
        guard let idx = list.firstIndex(where: { $0.id == selectedID }), idx < list.count - 1 else { return }
        selectedID = list[idx + 1].id
    }

    func moveUp() {
        let list = filteredStations
        guard let idx = list.firstIndex(where: { $0.id == selectedID }), idx > 0 else { return }
        selectedID = list[idx - 1].id
    }

    func moveFavoriteDown() {
        let favs = favoriteStations
        guard let idx = favs.firstIndex(where: { $0.id == selectedID }), idx < favs.count - 1 else { return }
        selectedID = favs[idx + 1].id
    }

    func moveFavoriteUp() {
        let favs = favoriteStations
        guard let idx = favs.firstIndex(where: { $0.id == selectedID }), idx > 0 else { return }
        selectedID = favs[idx - 1].id
    }

    func nextGenre() {
        guard !isTransitioning, selectedGenreIndex < Genre.allCases.count - 1 else { return }
        slideDirection = .right
        isTransitioning = true
        selectedGenreIndex += 1
        clampSelectionToFilter()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.isTransitioning = false }
    }

    func prevGenre() {
        guard !isTransitioning, selectedGenreIndex > 0 else { return }
        slideDirection = .left
        isTransitioning = true
        selectedGenreIndex -= 1
        clampSelectionToFilter()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.isTransitioning = false }
    }

    func togglePlayback() {
        if playingID == selectedID {
            playingID = nil
        } else {
            playingID = selectedID
        }
    }

    func toggleFavorite() {
        if favorites.contains(selectedID) {
            favorites.remove(selectedID)
        } else {
            favorites.insert(selectedID)
        }
    }

    func switchToNowPlaying() {
        if let pid = playingID {
            selectedID = pid
        } else if !favorites.contains(selectedID), let first = favoriteStations.first {
            selectedID = first.id
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            currentView = .nowPlaying
        }
    }

    func switchToStations() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            currentView = .stations
        }
    }

    private func clampSelectionToFilter() {
        let list = filteredStations
        guard !list.isEmpty else {
            print("[DEBUG][AppState] clampSelectionToFilter — list empty for genre: \(selectedGenre.rawValue)")
            return
        }
        if !list.contains(where: { $0.id == selectedID }) {
            selectedID = list[0].id
            print("[DEBUG][AppState] clampSelectionToFilter — snapped to: \(list[0].name)")
        }
    }
}
