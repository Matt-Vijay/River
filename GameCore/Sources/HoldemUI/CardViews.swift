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

/// A single card. `card == nil` renders the face-down back.
struct PlayingCardView: View {
    let card: Card?
    let width: CGFloat
    let height: CGFloat
    /// Dimmed at showdown when the card isn't part of a winning hand.
    var dimmed: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner, style: .continuous)
        shape.fill(card == nil ? Theme.cardBackTint : Theme.cardFace)
            .overlay { shape.strokeBorder(.black.opacity(0.06), lineWidth: 0.5) }
            .overlay { content }
            .clipShape(shape)
            .frame(width: width, height: height)
            .opacity(card != nil && dimmed ? 0.55 : 1)
            .saturation(card != nil && dimmed ? 0.5 : 1)
    }

    @ViewBuilder
    private var content: some View {
        if let card {
            ZStack {
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.5, weight: .semibold))
                    .offset(y: height * 0.08)

                Text(card.rank.label)
                    .font(.system(size: width * 0.36, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, width * 0.12)
                    .padding(.vertical, height * 0.06)
            }
            .foregroundStyle(card.suit.color)
        } else {
            Image(systemName: "suit.spade.fill")
                .font(.system(size: width * 0.28, weight: .semibold))
                .foregroundStyle(Theme.hatch)
        }
    }
}

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
                    .accessibilityIdentifier("table.pot")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            board.isEmpty
                ? "Board empty"
                : "Board: \(board.map(\.spokenDescription).joined(separator: ", "))"
        )
        .accessibilityIdentifier("table.board")
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
