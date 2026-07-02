import SwiftUI
import GameCore

struct CommunityCardsView: View {
    let board: [Card]
    var winningCards: Set<Card>? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                let card = index < board.count ? board[index] : nil
                PlayingCardView(card: card, dimmed: isDimmed(card))
            }
        }
    }

    private func isDimmed(_ card: Card?) -> Bool {
        guard let card, let winningCards else { return false }
        return !winningCards.contains(card)
    }
}
