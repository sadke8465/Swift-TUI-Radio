import SwiftUI

// MARK: - GenreTabsView
// Horizontally scrollable tab bar with animated sliding underline.
// Spec §5.1.1 — matchedGeometryEffect for underline, Snappy spring.

struct GenreTabsView: View {
    @Binding var selectedIndex: Int
    let onSelect: (Int) -> Void

    @Namespace private var underlineNS

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
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func tabButton(index: Int, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedIndex == index
        Button {
            onSelect(index)
        } label: {
            VStack(spacing: 2) {
                Text(Genre.allCases[index].rawValue)
                    .font(.appFont)
                    .foregroundColor(.charcoal)
                    .opacity(isSelected ? 1.0 : 0.4)
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: selectedIndex)

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
    }
}
