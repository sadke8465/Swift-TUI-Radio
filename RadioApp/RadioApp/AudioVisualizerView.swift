import SwiftUI

// MARK: - AudioVisualizerView
// Canvas-based 44-bar animated spectrum per spec §8.

struct AudioVisualizerView: View {
    var isPlaying: Bool

    private let barCount = 44
    private let gap: CGFloat = 1.5
    private let minHeight: CGFloat = 2

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { context, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let totalGap  = gap * CGFloat(barCount - 1)
                let barWidth  = (size.width - totalGap) / CGFloat(barCount)

                for i in 0..<barCount {
                    let pos = Double(i) / Double(barCount - 1)
                    let target = computeTarget(t: t, pos: pos)
                    let barH   = max(minHeight, CGFloat(target) * size.height)
                    let x      = CGFloat(i) * (barWidth + gap)
                    let y      = size.height - barH
                    let alpha  = 0.22 + target * 0.55

                    context.fill(
                        Path(CGRect(x: x, y: y, width: barWidth, height: barH)),
                        with: .color(Color.white.opacity(alpha))
                    )
                }
            }
        }
    }

    private func computeTarget(t: Double, pos: Double) -> Double {
        if isPlaying {
            return min(0.94,
                0.15
                + 0.32 * abs(sin(t * 1.8 + pos * .pi * 3.5))
                + 0.22 * abs(sin(t * 2.9 + pos * .pi * 6.0 + 1.2))
                + 0.12 * abs(sin(t * 4.1 + pos * .pi * 1.5 + 2.5))
            )
        } else {
            return 0.02 + 0.018 * abs(sin(t * 0.4 + pos * 8))
        }
    }
}
