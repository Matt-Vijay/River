import SwiftUI
import GameCore

/// A rounded-rect border that shrinks lengthwise around its perimeter as the
/// turn clock runs out. Starts at top-centre and depletes clockwise.
struct DepletingBorder: View {
    let startedAt: Date
    let duration: TimeInterval
    let cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation) { context in
            let duration = TurnClock.normalized(duration)
            let elapsed = context.date.timeIntervalSince(startedAt)
            let remaining = max(0, min(1, 1 - elapsed / duration))
            TimerBorderShape(cornerRadius: cornerRadius)
                .trim(from: 0, to: remaining)
                .stroke(remaining < 0.25 ? Theme.warn : Theme.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}
