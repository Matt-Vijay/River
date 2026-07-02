import SwiftUI
import GameCore

/// Your two hole cards, side by side. Swipe them up to fold when allowed.
struct HoleCardsView: View {
    let cards: [Card]
    var highlight: Set<Card>? = nil
    var onFold: (() -> Void)? = nil

    @State private var dragY: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            if cards.count >= 2 {
                PlayingCardView(card: cards[0],
                                width: Theme.Metrics.holeCardWidth,
                                height: Theme.Metrics.holeCardHeight,
                                dimmed: isDimmed(cards[0]))
                PlayingCardView(card: cards[1],
                                width: Theme.Metrics.holeCardWidth,
                                height: Theme.Metrics.holeCardHeight,
                                dimmed: isDimmed(cards[1]))
            } else {
                PlayingCardView(card: nil,
                                width: Theme.Metrics.holeCardWidth,
                                height: Theme.Metrics.holeCardHeight)
            }
        }
        .offset(y: dragY)
        .opacity(1 - Double(min(-dragY, 120)) / 240)
        .gesture(onFold == nil ? nil : foldDrag)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(onFold == nil ? "Your hole cards" : "Your hole cards. Swipe up to fold.")
        .accessibilityIdentifier(HoldemAccessibility.Table.holeCards)
    }

    private func isDimmed(_ card: Card) -> Bool {
        guard let highlight else { return false }
        return !highlight.contains(card)
    }

    private var foldDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                dragY = min(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height < -80 {
                    withAnimation(.tableSnap) { dragY = 0 }
                    onFold?()
                } else {
                    withAnimation(.tableSnap) { dragY = 0 }
                }
            }
    }
}
