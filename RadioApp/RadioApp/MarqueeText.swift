import SwiftUI

// MARK: - MarqueeText
// Overflow-detecting, auto-scrolling text.
// Spec §6: 30 pt/s, 60 px gap, 0.5 s initial delay, linear, infinite loop.

struct MarqueeText: View {
    let text: String
    var color: Color = .charcoal
    var isActive: Bool = true

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var activationTime: Date = Date()

    private let speed: Double = 30      // points per second
    private let gap: Double   = 60      // px gap between end and next copy
    private let delay: Double = 0.5    // seconds before scrolling begins

    private var isOverflowing: Bool { textWidth > containerWidth + 1 }
    private var shouldScroll: Bool   { isActive && isOverflowing }
    private var cycleWidth: Double   { Double(textWidth) + gap }

    var body: some View {
        ZStack(alignment: .leading) {
            if shouldScroll {
                TimelineView(.animation) { ctx in
                    let offset = computeOffset(now: ctx.date)
                    HStack(spacing: CGFloat(gap)) {
                        singleText
                        singleText
                    }
                    .fixedSize()
                    .offset(x: CGFloat(offset))
                }
            } else {
                singleText
                    .lineLimit(1)
            }
        }
        // Measure container width
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear    { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { containerWidth = $0 }
            }
        )
        // Measure natural text width via hidden background text
        .background(
            singleText
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear    { textWidth = geo.size.width }
                            .onChange(of: geo.size.width) { textWidth = $0 }
                    }
                )
        )
        .clipped()
        .frame(maxWidth: .infinity, alignment: .leading)
        // Reset scroll timer when activation or text changes
        .onChange(of: isActive) { active in
            if active { activationTime = Date() }
        }
        .onChange(of: text) { _ in
            activationTime = Date()
        }
        .onAppear {
            activationTime = Date()
        }
    }

    private var singleText: some View {
        Text(text)
            .font(.appFont)
            .foregroundColor(color)
            .fixedSize()
    }

    private func computeOffset(now: Date) -> Double {
        guard shouldScroll, cycleWidth > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(activationTime)
        guard elapsed > delay else { return 0 }
        let adjusted  = elapsed - delay
        let position  = (adjusted * speed).truncatingRemainder(dividingBy: cycleWidth)
        return -position
    }
}
