import SwiftUI
import GameCore

/// Bottom-right box showing your live hand strength, avatar and stack.
struct HandStrengthBox: View {
    let name: String
    let avatar: String
    let stack: Int
    let handName: String?
    var turnStart: Date? = nil
    var turnDuration: TimeInterval = TurnClock.defaultDuration
    var highlightWin: Bool = false

    private let corner: CGFloat = 18

    var body: some View {
        VStack(spacing: 3) {
            Text(handName ?? " ")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.opacity)
                .animation(.tableSnap, value: handName)
            Text(avatar)
                .font(.system(size: 32))
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(ChipFormatter.string(stack))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(highlightWin ? Theme.accent : .white)
                .contentTransition(.numericText())
        }
        .frame(width: Theme.Metrics.holeCardHeight, height: Theme.Metrics.holeCardHeight)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.controlBackground)
        )
        .overlay { borderOverlay }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(HoldemAccessibility.Table.heroSeat)
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if let turnStart {
            DepletingBorder(startedAt: turnStart, duration: turnDuration, cornerRadius: corner)
        } else {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Theme.accent, lineWidth: 1.5)
        }
    }

    private var accessibilityLabel: String {
        var parts = [name, "your seat", "stack \(ChipFormatter.string(stack))"]
        if let handName { parts.append(handName) }
        if turnStart != nil {
            parts.append("your turn")
            parts.append("\(Int(TurnClock.normalized(turnDuration))) second clock")
        }
        return parts.joined(separator: ", ")
    }
}
