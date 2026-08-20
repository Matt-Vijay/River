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
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                if let handLabel {
                    Text(handLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .stableOneLineText(minScale: 0.78)
                        .layoutPriority(1)
                }
                Spacer(minLength: 8)
                Text("Pot \(ChipText.string(pot))")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                    .stableOneLineText(minScale: 0.72)
                    .layoutPriority(1)
                    .accessibilityLabel("Pot")
                    .accessibilityValue(ChipText.string(pot))
                    .accessibilityIdentifier(HoldemAccessibility.Table.pot)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            board.isEmpty
                ? "Board empty"
                : "Board: \(board.map(\.spokenDescription).joined(separator: ", "))"
        )
        .accessibilityIdentifier(HoldemAccessibility.Table.board)
    }
}

private struct CommunityCardsView: View {
    let board: [Card]
    var winningCards: Set<Card>? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            cards(width: Theme.Metrics.boardCardWidth,
                  height: Theme.Metrics.boardCardHeight,
                  spacing: 6)
            cards(width: 50, height: 71, spacing: 6)
            cards(width: 44, height: 62, spacing: 4)
        }
    }

    private func cards(width: CGFloat, height: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { index in
                let card = index < board.count ? board[index] : nil
                if let card {
                    PlayingCardView(card: card,
                                    width: width,
                                    height: height,
                                    dimmed: winningCards?.contains(card) == false)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                        .fill(Theme.controlBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                                .strokeBorder(Theme.controlStroke, lineWidth: 1)
                        }
                        .frame(width: width, height: height)
                }
            }
        }
    }

}
