import SwiftUI
import AppKit

// MARK: - ContentView
// Root container: ZStack crossfade of both views + keyboard handling.
// Spec §7.2, §9.

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        ZStack {
            Color.backdrop.ignoresSafeArea()

            // Card container — both views stacked, crossfading
            ZStack {
                // All Stations (light)
                AllStationsView(state: state)
                    .opacity(state.currentView == .stations ? 1 : 0)
                    .scaleEffect(state.currentView == .stations ? 1 : 0.98)
                    .offset(y: state.currentView == .stations ? 0 : -10)
                    .allowsHitTesting(state.currentView == .stations)
                    .animation(.spring(response: 0.4, dampingFraction: 0.78), value: state.currentView)

                // Now Playing (dark)
                NowPlayingView(state: state)
                    .opacity(state.currentView == .nowPlaying ? 1 : 0)
                    .scaleEffect(state.currentView == .nowPlaying ? 1 : 0.98)
                    .offset(y: state.currentView == .nowPlaying ? 0 : 10)
                    .allowsHitTesting(state.currentView == .nowPlaying)
                    .animation(.spring(response: 0.4, dampingFraction: 0.78), value: state.currentView)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            // Dual-layer drop shadow per spec §2
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
        }
        .frame(width: 200, height: 400)
        .onAppear(perform: setupKeyboardMonitor)
        .task { await state.loadAllData() }
    }

    // MARK: - Keyboard Monitor

    @State private var keyMonitor: Any? = nil

    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event: event)
            return nil // consume all key events
        }
    }

    private func handleKey(event: NSEvent) {
        switch event.keyCode {
        case 125: // Arrow Down
            if state.currentView == .stations { state.moveDown() }
            else { state.moveFavoriteDown() }

        case 126: // Arrow Up
            if state.currentView == .stations { state.moveUp() }
            else { state.moveFavoriteUp() }

        case 124: // Arrow Right
            if state.currentView == .stations { state.nextGenre() }

        case 123: // Arrow Left
            if state.currentView == .stations { state.prevGenre() }

        case 49: // Space
            state.togglePlayback()

        case 53: // Escape
            if state.currentView == .nowPlaying { state.switchToStations() }

        default:
            if let char = event.charactersIgnoringModifiers?.lowercased() {
                switch char {
                case "f": state.toggleFavorite()
                case "n":
                    if state.currentView == .stations { state.switchToNowPlaying() }
                    else { state.switchToStations() }
                default: break
                }
            }
        }
    }
}
