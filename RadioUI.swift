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

private static let separator = "   "
private static let scrollSpeed: CGFloat = 40.0 // points per second

// startDate marks when scrolling should begin (set after the startup delay)
@State private var startDate: Date? = nil
@State private var delayTask: Task<Void, Never>? = nil

// Accurate monospaced advance width measured once via CoreText
private static let charWidth: CGFloat = {
    let nsFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    let ctFont = nsFont as CTFont
    var glyph = CGGlyph(0)
    var char = UniChar(("M" as UnicodeScalar).value)
    CTFontGetGlyphsForCharacters(ctFont, &char, &glyph, 1)
    var advance = CGSize.zero
    CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &advance, 1)
    let w = advance.width
    return (w > 4 && w < 20) ? w : 8.4
}()

// Render text + gap + text so the seamless reset is invisible
private var doubledText: String { text + Self.separator + text }

var body: some View {
    GeometryReader { geo in
        let viewWidth = geo.size.width
        // cycleWidth is one full loop distance: text + separator
        let cycleWidth = CGFloat(text.count + Self.separator.count) * Self.charWidth
        let needsScroll = cycleWidth > viewWidth && isSelected

        // Use TimelineView so the offset is derived from wall-clock time rather
        // than SwiftUI animation state. This is immune to parent view re-renders
        // (e.g. the visualizer timer firing every 70 ms), which is what caused
        // the jitter with the previous withAnimation(.repeatForever) approach.
        Group {
            if needsScroll, let start = startDate {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    let distance = CGFloat(elapsed) * Self.scrollSpeed
                    let xOffset = -(distance.truncatingRemainder(dividingBy: cycleWidth))
                    Text(doubledText)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: xOffset)
                        .frame(width: viewWidth, alignment: .leading)
                        .clipped()
                }
            } else {
                Text(text)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: viewWidth, alignment: .leading)
                    .clipped()
            }
        }
        .onAppear {
            if needsScroll { scheduleAnimation(cycleWidth: cycleWidth) }
        }
        .onChange(of: isSelected) { _, selected in
            cancelAndReset()
            let cw = CGFloat(text.count + Self.separator.count) * Self.charWidth
            if selected && cw > viewWidth { scheduleAnimation(cycleWidth: cw) }
        }
        .onChange(of: text) { _, newText in
            cancelAndReset()
            let cw = CGFloat(newText.count + Self.separator.count) * Self.charWidth
            if isSelected && cw > viewWidth { scheduleAnimation(cycleWidth: cw) }
        }
        .onDisappear { cancelAndReset() }
    }
    .frame(height: 18)
}

private func cancelAndReset() {
    delayTask?.cancel()
    delayTask = nil
    startDate = nil
}

private func scheduleAnimation(cycleWidth: CGFloat) {
    delayTask = Task {
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s startup pause
        guard !Task.isCancelled else { return }
        await MainActor.run { startDate = Date() }
    }
}

}

// MARK: - Main View
struct RadioUI: View {

// MARK: - State
@State private var focus: AppFocus = .main
@State private var keyboardMonitorInstalled = false
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
            .contentTransition(.identity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 24)
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
                .contentTransition(.identity)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 24)
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
                                .contentTransition(.identity)
                            Text("ALL STATIONS..")
                                .font(.system(size: 14, design: .monospaced))
                            Spacer()
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .id("all_link")
                    }
                }
                .scrollIndicators(.hidden)
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
            .scrollIndicators(.hidden)
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
            .contentTransition(.identity)
            .foregroundColor(.black)

        MarqueeText(text: name, isSelected: isSelected)
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.black)

        Text(isFavorite ? "♥︎" : " ")
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.black)
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
    guard !keyboardMonitorInstalled else { return }
    keyboardMonitorInstalled = true
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
    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.2
        ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        NSApplication.shared.windows.first?.animator().setContentSize(
            NSSize(width: windowWidth * 2, height: windowHeight)
        )
    }
}

private func closeAllStations() {
    withAnimation(.easeInOut(duration: 0.2)) { showAllStations = false }
    focus = .main
    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.2
        ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        NSApplication.shared.windows.first?.animator().setContentSize(
            NSSize(width: windowWidth, height: windowHeight)
        )
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
