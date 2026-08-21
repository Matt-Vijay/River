import SwiftUI
import GameCore

private struct TableNowKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

extension EnvironmentValues {
    var tableNow: Date? {
        get { self[TableNowKey.self] }
        set { self[TableNowKey.self] = newValue }
    }
}

private struct TurnClockAccessibilityValue: ViewModifier {
    @Environment(\.tableNow) private var now

    let startedAt: Date?
    let duration: TimeInterval

    func body(content: Content) -> some View {
        guard let startedAt else { return content.accessibilityValue("") }
        let seconds = TurnClock.remainingSeconds(
            startedAt: startedAt,
            duration: duration,
            at: now ?? Date()
        )
        let value = seconds == 1
            ? "1 second remaining"
            : seconds > 0 ? "\(seconds) seconds remaining" : "Turn expired"
        return content.accessibilityValue(value)
    }
}

extension View {
    func turnClockAccessibilityValue(startedAt: Date?, duration: TimeInterval) -> some View {
        modifier(TurnClockAccessibilityValue(startedAt: startedAt, duration: duration))
    }
}

struct CountdownTimer: View {
    let startedAt: Date
    let duration: TimeInterval

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let remaining = TurnClock.remainingFraction(
                startedAt: startedAt, duration: duration, at: timeline.date
            )
            PieShape(fraction: remaining)
                .fill(remaining < 0.25 ? Theme.warn : Theme.accent)
        }
    }
}

private struct PieShape: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        guard fraction > 0 else { return path }
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * fraction),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct DepletingBorder: View {
    let startedAt: Date
    let duration: TimeInterval
    let cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let remaining = TurnClock.remainingFraction(
                startedAt: startedAt, duration: duration, at: timeline.date
            )
            RoundedRectangle(cornerRadius: cornerRadius)
                .trim(from: 0, to: remaining)
                .stroke(remaining < 0.25 ? Theme.warn : Theme.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}
