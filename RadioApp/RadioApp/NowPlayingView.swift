import SwiftUI

// MARK: - NowPlayingView
// Dark-themed view: NOW PLAYING card + Favorites card.
// Spec §5.2.

struct NowPlayingView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 4) {
            nowPlayingCard
            favoritesCard
        }
        .padding(4)
        .background(Color.tagBackground)
    }

    // MARK: - Top Card

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text("NOW PLAYING")
                .font(.appFont)
                .foregroundColor(.white)

            ThinDivider()

            // Station info
            stationInfo

            ThinDivider()

            // Audio visualizer — fills remaining space
            AudioVisualizerView(isPlaying: state.playingID != nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .padding(.horizontal, 6)
        .background(Color.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var stationInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Star + name row
            HStack(spacing: 0) {
                FavoriteStarView(
                    isFavorite: state.favorites.contains(state.selectedID),
                    color: .white
                )
                if state.favorites.contains(state.selectedID) {
                    Spacer().frame(width: 3)
                }

                if let station = state.playingStation {
                    MarqueeText(text: station.name, color: .white, isActive: true)
                } else {
                    Text("— press Space to play —")
                        .font(.appFont)
                        .foregroundColor(.white)
                        .opacity(0.6)
                }
            }
            .frame(height: 15)

            // Frequency + country tags (conditional)
            if let station = state.playingStation {
                HStack(spacing: 4) {
                    TagView(label: station.frequency, darkText: true)
                    TagView(label: station.country, darkText: true)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: state.playingID)
            }
        }
    }

    // MARK: - Favorites Card

    private var favoritesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: 8, height: 8)
                Text("Favorites")
                    .font(.appFont)
                    .foregroundColor(.white)
            }

            ThinDivider()

            // Favorites list
            if state.favoriteStations.isEmpty {
                Text("No favorites yet")
                    .font(.appFont)
                    .foregroundColor(.white.opacity(0.35))
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.favoriteStations) { station in
                        favoriteRow(station: station)
                    }
                }
            }

            ThinDivider()

            // All Stations link
            allStationsLink
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }

    private func favoriteRow(station: Station) -> some View {
        let isSelected = station.id == state.selectedID
        return HStack(spacing: 0) {
            // Selector ">" indicator — Snappy spring per spec §7.9
            Text(">")
                .font(.appFont)
                .foregroundColor(.white)
                .frame(width: isSelected ? 8 : 0)
                .opacity(isSelected ? 1 : 0)
                .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isSelected)

            Spacer().frame(width: isSelected ? 4 : 0)
                .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isSelected)

            MarqueeText(text: station.name, color: .white, isActive: isSelected)
        }
        .frame(height: 15)
    }

    private var allStationsLink: some View {
        AllStationsLink {
            state.switchToStations()
        }
    }
}

// MARK: - All Stations Hover Link

private struct AllStationsLink: View {
    let action: () -> Void
    @State private var isHovered  = false
    @State private var isPressed  = false

    var body: some View {
        HStack(spacing: 3) {
            Text("All Stations")
                .font(.appFont)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                // Arrow nudges right on hover — physical direction cue
                .offset(x: isHovered ? 2 : 0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        }
        .foregroundColor(.white)
        // Three-tier opacity: pressed dim, hovered full, default subtle
        .opacity(isPressed ? 0.55 : (isHovered ? 1.0 : 0.65))
        // Subtle scale-down on press — physical depth
        .scaleEffect(isPressed ? 0.96 : 1.0, anchor: .leading)
        .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isHovered)
        .animation(.spring(response: 0.14, dampingFraction: 0.65), value: isPressed)
        .onHover { hovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.78)) {
                isHovered = hovering
            }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.14, dampingFraction: 0.65)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                        isPressed = false
                    }
                    action()
                }
        )
    }
}
