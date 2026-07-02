import SwiftUI
import GameCore

/// The five community card slots, the pot total, and (at showdown) the winning
/// hand label plus dimming of cards outside the winning five.
struct BoardView: View {
    let board: [Card]
    let pot: Int
    /// The winning five cards at showdown; non-members get dimmed. Nil mid-hand.
    var winningCards: Set<Card>? = nil
    var handLabel: String? = nil

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            CommunityCardsView(board: board, winningCards: winningCards)
            BoardStatusRow(pot: pot, handLabel: handLabel)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(HoldemAccessibility.Table.board)
    }

    private var accessibilityLabel: String {
        if board.isEmpty {
            return "Board empty"
        }
        return "Board: \(board.map(\.description).joined(separator: " "))"
    }
}

#Preview("Board") {
    VStack(spacing: 30) {
        BoardView(board: [
            Card(rank: .five, suit: .diamonds),
            Card(rank: .eight, suit: .clubs),
            Card(rank: .eight, suit: .hearts),
        ], pot: 120)

        BoardView(board: [
            Card(rank: .six, suit: .clubs),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .two, suit: .clubs),
            Card(rank: .eight, suit: .hearts),
            Card(rank: .seven, suit: .clubs),
        ], pot: 32,
        winningCards: [
            Card(rank: .six, suit: .clubs),
            Card(rank: .two, suit: .clubs),
            Card(rank: .seven, suit: .clubs),
        ], handLabel: "Flush")
    }
    .padding()
    .background(Theme.background)
}
