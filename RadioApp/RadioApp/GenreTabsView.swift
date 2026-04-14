import SwiftUI

// MARK: - GenreTabsView
// Horizontally scrollable tab bar with animated sliding underline.
// Spec §5.1.1 — matchedGeometryEffect for underline, snappy spring.

struct GenreTabsView: View {
    @Binding var selectedIndex: Int
    let onSelect: (Int) -> Void

    @Namespace private var underlineNS
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Genre.allCases.indices, id: \.self) { index in
                        tabButton(index: index, proxy: proxy)
                            .id(index)
                    }
                }
                .padding(.bottom, 4)
            }
            .onChange(of: selectedIndex) { idx in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func tabButton(index: Int, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedIndex == index
        let isHovered  = hoveredIndex == index
        Button {
            onSelect(index)
        } label: {
            VStack(spacing: 2) {
                Text(Genre.allCases[index].rawValue)
                    .font(.appFont)
                    .foregroundColor(.charcoal)
                    // Three-tier opacity: selected full, hovered mid, default dim
                    .opacity(isSelected ? 1.0 : (isHovered ? 0.7 : 0.4))
                    .animation(.spring(response: 0.2, dampingFraction: 0.82), value: selectedIndex)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: hoveredIndex)

                if isSelected {
                    Rectangle()
                        .fill(Color.cardDark)
                        .frame(height: 1)
                        .matchedGeometryEffect(id: "underline", in: underlineNS)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) {
                hoveredIndex = hovering ? index : nil
            }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
