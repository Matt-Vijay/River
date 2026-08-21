import SwiftUI
import GameCore

extension Card {
    var spokenDescription: String {
        let spokenRank = switch rank {
        case .two, .three, .four, .five, .six, .seven, .eight, .nine:
            String(rank.rawValue)
        case .ten: "ten"
        case .jack: "jack"
        case .queen: "queen"
        case .king: "king"
        case .ace: "ace"
        }
        let spokenSuit = switch suit {
        case .clubs: "clubs"
        case .diamonds: "diamonds"
        case .hearts: "hearts"
        case .spades: "spades"
        }
        return "\(spokenRank) of \(spokenSuit)"
    }
}

/// A single card. `card == nil` renders the hatched face-down back.
struct PlayingCardView: View {
    let card: Card?
    let width: CGFloat
    let height: CGFloat
    /// Dimmed at showdown when the card isn't part of a winning hand.
    var dimmed: Bool = false

    var body: some View {
        if let card {
            CardSurface(width: width, height: height) {
                CardFace(card: card, width: width, height: height)
            }
            .opacity(dimmed ? 0.55 : 1)
            .saturation(dimmed ? 0.5 : 1)
        } else {
            CardSurface(width: width, height: height, isBack: true) {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: width * 0.28, weight: .semibold))
                    .foregroundStyle(Theme.hatch)
            }
        }
    }
}

private struct CardSurface<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    var isBack = false
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner, style: .continuous)
            .fill(isBack ? Theme.cardBackTint : Theme.cardFace)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner, style: .continuous)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
            )
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner, style: .continuous))
            .frame(width: width, height: height)
    }
}

private struct CardFace: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            Text(card.suit.symbol)
                .font(.system(size: width * 0.5, weight: .semibold))
                .foregroundStyle(card.suit.color)
                .offset(y: height * 0.08)

            Text(card.rank.label)
                .font(.system(size: width * 0.36, weight: .bold))
                .foregroundStyle(card.suit.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, width * 0.12)
                .padding(.vertical, height * 0.06)
        }
    }
}
