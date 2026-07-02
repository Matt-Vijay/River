import SwiftUI
import GameCore

/// A single card. `card == nil` renders the hatched face-down back. When `card`
/// transitions from nil to a value the card flips face-up with a 3D animation.
struct PlayingCardView: View {
    let card: Card?
    var width: CGFloat = Theme.Metrics.boardCardWidth
    var height: CGFloat = Theme.Metrics.boardCardHeight
    /// Dimmed at showdown when the card isn't part of a winning hand.
    var dimmed: Bool = false

    private var faceUp: Bool { card != nil }

    var body: some View {
        ZStack {
            CardSurface(width: width, height: height) {
                if let card { CardFace(card: card, width: width, height: height) }
            }
            .opacity(faceUp ? 1 : 0)

            CardSurface(width: width, height: height, isBack: true) {
                HatchBack().padding(5)
            }
            .opacity(faceUp ? 0 : 1)
        }
        .frame(width: width, height: height)
        .rotation3DEffect(.degrees(faceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .opacity(dimmed ? 0.55 : 1)
        .saturation(dimmed ? 0.5 : 1)
        .animation(.tableSnap, value: faceUp)
        .animation(.tableSnap, value: dimmed)
    }
}

#Preview("Cards") {
    HStack {
        PlayingCardView(card: Card(rank: .ace, suit: .spades))
        PlayingCardView(card: Card(rank: .ten, suit: .hearts))
        PlayingCardView(card: nil)
        PlayingCardView(card: Card(rank: .eight, suit: .diamonds), dimmed: true)
    }
    .padding()
    .background(Theme.background)
}
