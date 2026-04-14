import SwiftUI

// MARK: - StationRowView
// Expandable white card per spec §5.1.2.

struct StationRowView: View {
    let station: Station
    var isSelected: Bool
    var isPlaying: Bool
    var isFavorite: Bool

    @State private var isHovering: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Name row
            HStack(spacing: 0) {
                FavoriteStarView(isFavorite: isFavorite, color: .charcoal)
                if isFavorite {
                    Spacer().frame(width: 3)
                }

                PlayIndicatorView(isPlaying: isPlaying, color: .charcoal)
                if isPlaying {
                    Spacer().frame(width: 3)
                }

                if isSelected {
                    MarqueeText(text: station.name, color: .charcoal, isActive: true)
                } else {
                    // Clip without ellipsis
                    ZStack(alignment: .leading) {
                        Text(station.name)
                            .font(.appFont)
                            .foregroundColor(.charcoal)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                }
            }
            .frame(height: 15)

            // Detail row — only when selected
            if isSelected {
                HStack(spacing: 4) {
                    TagView(label: station.frequency)
                    TagView(label: station.country)
                }
                .padding(.top, 8)
                .transition(
                    .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                )
            }
        }
        .padding(6)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        // Three-tier shadow: selected elevated, hovered lifted, default subtle
        .shadow(
            color: .black.opacity(isSelected ? 0.12 : (isHovering ? 0.09 : 0.06)),
            radius: isSelected ? 3 : (isHovering ? 2 : 1)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovering = hovering
            }
        }
    }
}
