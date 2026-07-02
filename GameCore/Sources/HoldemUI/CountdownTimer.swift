import SwiftUI
import GameCore

/// Live turn clock: a green pie that depletes over `duration`, turning amber as
/// it runs low. Driven by `TimelineView(.animation)` so it ticks smoothly while
/// visible and renders a correct snapshot off-screen.
struct CountdownTimer: View {
    let startedAt: Date
    let duration: TimeInterval

    var body: some View {
        TimelineView(.animation) { context in
            let duration = TurnClock.normalized(duration)
            let elapsed = context.date.timeIntervalSince(startedAt)
            let remaining = max(0, min(1, 1 - elapsed / duration))
            PieShape(fraction: remaining)
                .fill(remaining < 0.25 ? Theme.warn : Theme.accent)
        }
    }
}
