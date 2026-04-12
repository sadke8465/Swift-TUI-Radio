import SwiftUI
import AppKit
import Combine

// MARK: - Data Models
struct Station: Identifiable, Equatable {
let id = UUID()
let name: String
}

enum AppFocus {
case main, allStations
}

// MARK: - Marquee Text
struct MarqueeText: View {
let text: String
let isSelected: Bool

@State private var offset: CGFloat = 0
@State private var animating: Bool = false

var body: some View {
    GeometryReader { geo in
        let charWidth: CGFloat = 8.4
        let textWidth = CGFloat(text.count) * charWidth
        let viewWidth = geo.size.width
        let needsScroll = textWidth > viewWidth && isSelected

        Text(text)
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: offset)
            .frame(width: viewWidth, alignment: .leading)
            .clipped()
            .onAppear {
                if needsScroll { triggerAnimation(textWidth: textWidth, viewWidth: viewWidth) }
            }
            .onChange(of: isSelected) { _, selected in
                stopAnimation()
                if selected && textWidth > viewWidth {
                    // Small delay so offset reset is visible before scroll starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        triggerAnimation(textWidth: textWidth, viewWidth: viewWidth)
                    }
                }
            }
    }
    .frame(height: 18)
}

private func stopAnimation() {
    withAnimation(.linear(duration: 0)) {
        offset = 0
    }
    animating = false
}

private func triggerAnimation(textWidth: CGFloat, viewWidth: CGFloat) {
    guard !animating else { return }
    animating = true
    let totalDist = textWidth - viewWidth + 16
    let duration = Double(totalDist) / 40.0
    withAnimation(
        Animation.linear(duration: duration)
            .delay(0.8)
            .repeatForever(autoreverses: false)
    ) {
        offset = -totalDist
    }
}

}

// MARK: - Main View
struct RadioUI: View {

// MARK: - State
@State private var focus: AppFocus = .main
@State private var mainActiveIndex: Int = 1
@State private var allStationsActiveIndex: Int = 0

@State private var volume: Double = 0.6
@State private var currentlyPlaying: String = "---"
@State private var favorites: [Station] = []
@State private var showAllStations: Bool = false

@State private var allStations: [Station] = (1...50).map {
    Station(name: "STATION \($0) — LONG SIGNAL NAME \($0)")
}

// Visualizer
@State private var visualizerFrameIndex: Int = 0
let timer = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()

// MARK: - Constants
let windowWidth: CGFloat = 212
let windowHeight: CGFloat = 424
let maxTicks = 18
let pulse = "⣀⣄⣆⣇⣷⣿⣷⣇⣆⣄⣀"

private var isPlaying: Bool { currentlyPlaying != "---" }

// MARK: - Body
var body: some View {
    HStack(spacing: 0) {
        mainPanel
            .frame(width: windowWidth, height: windowHeight)
            .background(Color.black)

        if showAllStations {
            Divider().background(Color.gray.opacity(0.4))
            allStationsPanel
                .frame(width: windowWidth, height: windowHeight)
                .background(Color.black)
                .transition(.move(edge: .trailing))
        }
    }
    .cornerRadius(8)
    .onAppear {
        setupWindow()
        setupKeyboardMonitor()
    }
    // Visualizer advances only when playing
    .onReceive(timer) { _ in
        if isPlaying { visualizerFrameIndex += 1 }
    }
}

// MARK: - Main Panel
private var mainPanel: some View {
    VStack(alignment: .leading, spacing: 4) {

        // Now Playing
        VStack(alignment: .leading, spacing: 2) {
            Text("NOW PLAYING")
                .font(.system(size: 14, weight: .light, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            MarqueeText(text: currentlyPlaying, isSelected: true)
                .font(.system(size: 14, weight: .light, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 2)

        // Visualizer
        Text(isPlaying ? calculatedVisualizerFrame : String(repeating: " ", count: 22))
            .font(.system(size: 14, design: .monospaced))
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .padding(.horizontal, 4)
            .background(Color.white)
            .cornerRadius(2)

        // Volume
        VStack(alignment: .leading, spacing: 4) {
            Text("Volume")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.black)
            Text(String(repeating: "░", count: Int(volume * Double(maxTicks))))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .padding(.horizontal, 4)
                .background(Color.black)
                .cornerRadius(2)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(focus == .main && mainActiveIndex == 0 ? Color.white : Color.white.opacity(0.8))
        .cornerRadius(2)

        // Favorites
        VStack(alignment: .leading, spacing: 4) {
            Text("FAVORITES")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.black)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<favorites.count, id: \.self) { i in
                            stationRow(
                                name: favorites[i].name,
                                isSelected: focus == .main && mainActiveIndex == i + 1,
                                isFavorite: true
                            )
                            .id(i)
                        }

                        // All Stations link
                        HStack(spacing: 4) {
                            Text(focus == .main && mainActiveIndex == favorites.count + 1 ? ">" : " ")
                                .font(.system(size: 14, design: .monospaced))
                            Text("ALL STATIONS..")
                                .font(.system(size: 14, design: .monospaced))
                            Spacer()
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .id("all_link")
                    }
                }
                .onChange(of: mainActiveIndex) { _, newVal in
                    withAnimation {
                        if newVal == favorites.count + 1 {
                            proxy.scrollTo("all_link", anchor: .bottom)
                        } else if newVal > 0 {
                            proxy.scrollTo(newVal - 1, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(2)

        Spacer()
    }
    .padding(8)
}

// MARK: - All Stations Panel
private var allStationsPanel: some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("ALL STATIONS (\(allStations.count))")
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<allStations.count, id: \.self) { i in
                        stationRow(
                            name: allStations[i].name,
                            isSelected: focus == .allStations && allStationsActiveIndex == i,
                            isFavorite: favorites.contains(where: { $0.id == allStations[i].id })
                        )
                        .id(i)
                    }
                }
            }
            .onChange(of: allStationsActiveIndex) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(2)
    }
    .padding(8)
}

// MARK: - Station Row
@ViewBuilder
private func stationRow(name: String, isSelected: Bool, isFavorite: Bool) -> some View {
    HStack(spacing: 4) {
        Text(isSelected ? ">" : " ")
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.black)

        MarqueeText(text: name, isSelected: isSelected)
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.black)

        if isFavorite {
            Text("♥︎")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.black)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

// MARK: - Visualizer
private var calculatedVisualizerFrame: String {
    let totalWidth = 22
    let animationRange = totalWidth + pulse.count
    let offset = (visualizerFrameIndex % animationRange) - pulse.count
    var characters = Array(repeating: " " as Character, count: totalWidth)
    let pulseArray = Array(pulse)
    for (i, char) in pulseArray.enumerated() {
        let targetIndex = offset + i
        if targetIndex >= 0 && targetIndex < totalWidth {
            characters[targetIndex] = char
        }
    }
    return String(characters)
}

// MARK: - Window Setup
private func setupWindow() {
    if let window = NSApplication.shared.windows.first {
        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
    }
}

// MARK: - Keyboard
private func setupKeyboardMonitor() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        let volStep = 0.05

        switch event.keyCode {
        case 126: // Up
            if focus == .main {
                mainActiveIndex = max(0, mainActiveIndex - 1)
            } else {
                allStationsActiveIndex = max(0, allStationsActiveIndex - 1)
            }
            return nil
        case 125: // Down
            if focus == .main {
                mainActiveIndex = min(favorites.count + 1, mainActiveIndex + 1)
            } else {
                allStationsActiveIndex = min(allStations.count - 1, allStationsActiveIndex + 1)
            }
            return nil
        case 123: // Left
            if focus == .main && mainActiveIndex == 0 {
                volume = max(0, volume - volStep)
            } else if focus == .allStations {
                closeAllStations()
            }
            return nil
        case 124: // Right
            if focus == .main && mainActiveIndex == 0 {
                volume = min(1, volume + volStep)
            }
            return nil
        case 36: // Enter
            if focus == .main {
                if mainActiveIndex > 0 && mainActiveIndex <= favorites.count {
                    currentlyPlaying = favorites[mainActiveIndex - 1].name
                } else if mainActiveIndex == favorites.count + 1 {
                    openAllStations()
                }
            } else {
                currentlyPlaying = allStations[allStationsActiveIndex].name
            }
            return nil
        case 3: // F
            if focus == .allStations {
                toggleFavorite(allStations[allStationsActiveIndex])
            }
            return nil
        case 53: // Escape
            closeAllStations()
            return nil
        default:
            return event
        }
    }
}

// MARK: - Actions
private func openAllStations() {
    withAnimation(.easeInOut(duration: 0.2)) { showAllStations = true }
    focus = .allStations
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        if let window = NSApplication.shared.windows.first {
            window.animator().setContentSize(NSSize(width: windowWidth * 2, height: windowHeight))
        }
    }
}

private func closeAllStations() {
    withAnimation(.easeInOut(duration: 0.2)) { showAllStations = false }
    focus = .main
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        if let window = NSApplication.shared.windows.first {
            window.animator().setContentSize(NSSize(width: windowWidth, height: windowHeight))
        }
    }
}

private func toggleFavorite(_ station: Station) {
    if let index = favorites.firstIndex(where: { $0.id == station.id }) {
        favorites.remove(at: index)
    } else {
        favorites.append(station)
    }
}

}
