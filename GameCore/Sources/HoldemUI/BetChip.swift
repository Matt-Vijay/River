import SwiftUI

/// Amber chip showing chips a player has put in during the current betting
/// round. Used under each seat and beside the hero's hand box.
struct BetChip: View {
    let amount: Int

    var body: some View {
        Text(ChipFormatter.string(amount))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.chip)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.chipBackground))
            .contentTransition(.numericText())
    }
}
