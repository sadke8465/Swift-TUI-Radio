import SwiftUI
import Combine

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
    let id: Int
    let name: String
    let frequency: String
    let country: String
    let genre: Genre
}

// MARK: - Station Catalog (25 stations: 9 News, 7 Jazz, 9 Rock)

let allStations: [Station] = [
    Station(id: 1,  name: "Chilango (CDMX) 105.3 FM — XHINFO-FM",              frequency: "105.3 FM", country: "MX", genre: .news),
    Station(id: 2,  name: "BBC World Service — International News Radio",        frequency: "198 LW",   country: "GB", genre: .news),
    Station(id: 3,  name: "NPR News — National Public Radio Network",            frequency: "90.9 FM",  country: "US", genre: .news),
    Station(id: 4,  name: "Radio France Info — 24/7 French News Broadcasting",  frequency: "105.5 FM", country: "FR", genre: .news),
    Station(id: 5,  name: "Deutsche Welle Radio — DW German International",     frequency: "6075 SW",  country: "DE", genre: .news),
    Station(id: 6,  name: "ABC Radio National — Australian Broadcasting Corp",  frequency: "576 AM",   country: "AU", genre: .news),
    Station(id: 7,  name: "Radio Canada International — CBC/RC Global Service", frequency: "91.5 FM",  country: "CA", genre: .news),
    Station(id: 8,  name: "WNYC New York Public Radio — WNYC-FM Manhattan",     frequency: "93.9 FM",  country: "US", genre: .news),
    Station(id: 9,  name: "NHK World Radio Japan — International Service",      frequency: "9.605 SW", country: "JP", genre: .news),

    Station(id: 10, name: "Jazz FM London — The Home of Jazz in the UK",        frequency: "102.2 FM", country: "GB", genre: .jazz),
    Station(id: 11, name: "WBGO Newark Jazz 88.3 — Jazz 88 New Jersey",         frequency: "88.3 FM",  country: "US", genre: .jazz),
    Station(id: 12, name: "Blue Note Radio Paris — French Jazz Selection",      frequency: "Online",   country: "FR", genre: .jazz),
    Station(id: 13, name: "Radio Swiss Jazz — Continuous Swiss Jazz Stream",    frequency: "Online",   country: "CH", genre: .jazz),
    Station(id: 14, name: "KKJZ Long Beach Jazz 88.1 — SoCal Jazz Radio",      frequency: "88.1 FM",  country: "US", genre: .jazz),
    Station(id: 15, name: "Jazz Radio Lyon — All Jazz All Night Long",          frequency: "98.7 FM",  country: "FR", genre: .jazz),
    Station(id: 16, name: "Smooth Jazz Chicago WJMK — 104.3 Smooth Hits",      frequency: "104.3 FM", country: "US", genre: .jazz),

    Station(id: 17, name: "Classic Rock 101.1 WRXP — New York's Best Rock",    frequency: "101.1 FM", country: "US", genre: .rock),
    Station(id: 18, name: "Kerrang! Radio UK — Rock Music Around the Clock",   frequency: "Online",   country: "GB", genre: .rock),
    Station(id: 19, name: "Radio Paradise — Eclectic Rock Paradise Mix",        frequency: "Online",   country: "US", genre: .rock),
    Station(id: 20, name: "Planet Rock UK — The Home of Classic Rock",          frequency: "Online",   country: "GB", genre: .rock),
    Station(id: 21, name: "KROQ Los Angeles — Almost Alternative Rock Radio",   frequency: "106.7 FM", country: "US", genre: .rock),
    Station(id: 22, name: "Radio Bob! Germany — Heavy Rock Non-Stop",           frequency: "Online",   country: "DE", genre: .rock),
    Station(id: 23, name: "Triple J Australia — Alternative Rock Youth Radio",  frequency: "104.9 FM", country: "AU", genre: .rock),
    Station(id: 24, name: "WXRT Chicago Rock — 93XRT Alternative Rock",         frequency: "93.1 FM",  country: "US", genre: .rock),
    Station(id: 25, name: "Rock Antenne Bayern — German Rock Classics Stream",  frequency: "Online",   country: "DE", genre: .rock),
]

// MARK: - App State

class AppState: ObservableObject {
    @Published var currentView: AppView = .stations
    @Published var selectedID: Int = 1
    @Published var playingID: Int? = nil
    @Published var favorites: Set<Int> = [1, 3, 6]
    @Published var selectedGenreIndex: Int = 0
    @Published var slideDirection: SlideDirection = .right
    @Published var isLoading: Bool = false
    @Published var hasFirstLoaded: Bool = false
    @Published var isTransitioning: Bool = false

    enum SlideDirection { case left, right }

    var selectedGenre: Genre { Genre.allCases[selectedGenreIndex] }

    var filteredStations: [Station] {
        selectedGenre == .all ? allStations : allStations.filter { $0.genre == selectedGenre }
    }

    var selectedStation: Station? { allStations.first { $0.id == selectedID } }
    var playingStation: Station? {
        guard let pid = playingID else { return nil }
        return allStations.first { $0.id == pid }
    }
    var favoriteStations: [Station] { allStations.filter { favorites.contains($0.id) } }

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
        // Pre-select logic per spec §9.2
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
        if !hasFirstLoaded {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                currentView = .stations
            }
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.isLoading = false
                self.hasFirstLoaded = true
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                currentView = .stations
            }
        }
    }

    private func clampSelectionToFilter() {
        let list = filteredStations
        guard !list.isEmpty else { return }
        if !list.contains(where: { $0.id == selectedID }) {
            selectedID = list[0].id
        }
    }
}
