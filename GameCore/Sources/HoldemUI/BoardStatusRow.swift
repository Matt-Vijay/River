import SwiftUI

struct BoardStatusRow: View {
    let pot: Int
    var handLabel: String? = nil

    var body: some View {
        HStack {
            if let handLabel {
                ShowdownHandBadge(title: handLabel)
            }
            Spacer()
            Text(ChipFormatter.string(pot))
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .accessibilityLabel("Pot")
                .accessibilityValue(ChipFormatter.string(pot))
                .accessibilityIdentifier(HoldemAccessibility.Table.pot)
        }
    }
}

private struct ShowdownHandBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.cardFace))
            .transition(.opacity)
    }
}
