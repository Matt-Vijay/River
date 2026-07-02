import SwiftUI
import GameCore

struct PlayerSeatCardReveal: View {
    var cards: [Card]?
    var highlight: Set<Card>?

    var body: some View {
        ZStack {
            if let cards, cards.count >= 2 {
                HStack(spacing: 3) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        PlayingCardView(card: card, width: 25, height: 35,
                                        dimmed: highlight.map { !$0.contains(card) } ?? false)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
