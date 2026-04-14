import SwiftUI

// MARK: - TagView
// Gray pill with text; supports white or dark text variant.

struct TagView: View {
    let label: String
    var darkText: Bool = false

    var body: some View {
        Text(label)
            .font(.appFont)
            .foregroundColor(darkText ? .cardDark : .white)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(Color.tagBackground)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - ThinDivider
// 0.5 px white horizontal line per spec §5.2.

struct ThinDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 0.5)
    }
}

// MARK: - FavoriteStarView
// Animated star that pops in (Spring) and collapses out (ease-in 0.18 s).

struct FavoriteStarView: View {
    var isFavorite: Bool
    var color: Color = .charcoal
    /// Expanded width when visible
    var expandedWidth: CGFloat = 13

    var body: some View {
        Image(systemName: "star.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: isFavorite ? 8 : 0, height: 8)
            .scaleEffect(isFavorite ? 1.0 : 0.0)
            .rotationEffect(.degrees(isFavorite ? 0 : -45))
            .opacity(isFavorite ? 1.0 : 0.0)
            // Asymmetric: bouncy spring pop-in, swift spring collapse
            .animation(
                isFavorite
                    ? .spring(response: 0.22, dampingFraction: 0.62)  // slight bounce
                    : .spring(response: 0.18, dampingFraction: 0.9),  // no-bounce fast exit
                value: isFavorite
            )
    }
}

// MARK: - PlayIndicatorView
// Animated play triangle with continuous pulse when visible.

struct PlayIndicatorView: View {
    var isPlaying: Bool
    var color: Color = .charcoal

    @State private var pulsing: Bool = false

    var body: some View {
        Image(systemName: "play.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: isPlaying ? 6 : 0, height: 6)
            .opacity(isPlaying ? 1.0 : 0.0)
            // Pulse (isolated layer)
            .scaleEffect(pulsing ? 0.85 : 1.0)
            .opacity(pulsing ? 0.5 : 1.0) // layered on top of show/hide opacity
            .animation(
                isPlaying
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : .spring(response: 0.18, dampingFraction: 0.9),
                value: pulsing
            )
            // Show/hide (separate layer via outer opacity)
            .animation(
                isPlaying
                    ? .spring(response: 0.2, dampingFraction: 0.68)
                    : .spring(response: 0.18, dampingFraction: 0.9),
                value: isPlaying
            )
            .onChange(of: isPlaying) { playing in
                if playing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        pulsing = true
                    }
                } else {
                    pulsing = false
                }
            }
            .onAppear {
                if isPlaying { pulsing = true }
            }
    }
}

// MARK: - LoadingStateView

struct LoadingStateView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("Loading")
                .font(.appFont)
                .foregroundColor(.charcoal)
            Text("☻")
                .font(.appFont)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("No stations")
                .font(.appFont)
                .foregroundColor(.charcoal)
            Text("☻")
                .font(.appFont)
                .rotationEffect(.degrees(180))
        }
    }
}
