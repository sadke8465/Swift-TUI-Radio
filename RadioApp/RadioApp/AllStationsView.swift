import SwiftUI

// MARK: - AllStationsView
// Light-themed view: genre tabs + station list (or loading/empty states).
// Spec §5.1.

struct AllStationsView: View {
    @ObservedObject var state: AppState

    // Trigger for staggered row entrance animation
    @State private var rowsVisible: Bool = false
    @State private var contentID: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GenreTabsView(selectedIndex: $state.selectedGenreIndex) { idx in
                guard !state.isTransitioning else { return }
                if idx > state.selectedGenreIndex { state.nextGenre() }
                else if idx < state.selectedGenreIndex { state.prevGenre() }
            }
            .padding(.top, 0)

            stationListArea
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color.cardLight)
        .onChange(of: state.selectedGenreIndex) { _ in
            // Trigger stagger re-entrance
            rowsVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                contentID += 1
                rowsVisible = true
            }
        }
        .onAppear {
            rowsVisible = true
        }
    }

    @ViewBuilder
    private var stationListArea: some View {
        if state.isLoading {
            Spacer()
            LoadingStateView()
                .frame(maxWidth: .infinity)
            Spacer()
        } else if state.filteredStations.isEmpty {
            Spacer()
            EmptyStateView()
                .frame(maxWidth: .infinity)
            Spacer()
        } else {
            stationList
        }
    }

    private var stationList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 5) {
                    ForEach(Array(state.filteredStations.enumerated()), id: \.element.id) { idx, station in
                        StationRowView(
                            station:    station,
                            isSelected: station.id == state.selectedID,
                            isPlaying:  station.id == state.playingID,
                            isFavorite: state.favorites.contains(station.id)
                        )
                        .opacity(rowsVisible ? 1 : 0)
                        .offset(y: rowsVisible ? 0 : 8)
                        .animation(
                            .spring(response: 0.28, dampingFraction: 0.74)
                                .delay(Double(idx) * 0.028),
                            value: rowsVisible
                        )
                        .id(station.id)
                    }
                }
                .id(contentID) // force re-render on genre change
                .padding(.vertical, 1)
            }
            .onChange(of: state.selectedID) { id in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            // Directional slide transition driven by slideDirection
            .transition(slideTransition)
            .animation(.spring(response: 0.26, dampingFraction: 0.84), value: contentID)
        }
    }

    private var slideTransition: AnyTransition {
        let (insertEdge, removeEdge): (Edge, Edge) = state.slideDirection == .right
            ? (.trailing, .leading)
            : (.leading, .trailing)
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: insertEdge))
                                .combined(with: .scale(scale: 0.97, anchor: .center)),
            removal:   .opacity.combined(with: .move(edge: removeEdge))
                                .combined(with: .scale(scale: 0.97, anchor: .center))
        )
    }
}
