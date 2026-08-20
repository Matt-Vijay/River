import SwiftUI
import GameCore

struct HeroHandDock: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let context: PokerTableContext

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 16) {
                holeCards
                handStrength
            }
            VStack(spacing: 12) {
                holeCards
                handStrength
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var holeCards: some View {
        HoleCardsView(
            cards: context.hero.holeCards,
            highlight: context.winningCards
        )
    }

    private var handStrength: some View {
        VStack(spacing: 3) {
            Text(context.heroHandName ?? " ")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(usesAccessibleLayout ? 2 : 1)
                .minimumScaleFactor(usesAccessibleLayout ? 1 : 0.72)
                .multilineTextAlignment(.center)
            Text(context.hero.avatar)
                .font(.system(size: 32))
            Text(context.hero.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(usesAccessibleLayout ? 2 : 1)
                .minimumScaleFactor(usesAccessibleLayout ? 1 : 0.7)
                .multilineTextAlignment(.center)
            Text(ChipText.string(context.hero.stack))
                .font(.headline)
                .foregroundStyle(context.didWin(context.hero) ? Theme.accent : .white)
        }
        .padding(.vertical, usesAccessibleLayout ? 12 : 0)
        .frame(width: usesAccessibleLayout ? 180 : Theme.Metrics.holeCardHeight)
        .frame(minHeight: Theme.Metrics.holeCardHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner, style: .continuous)
                .fill(Theme.controlBackground)
        )
        .overlay {
            if let turnStart {
                DepletingBorder(startedAt: turnStart,
                                duration: context.state.turnDuration,
                                cornerRadius: Theme.Metrics.controlCorner)
            } else {
                RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner, style: .continuous)
                    .strokeBorder(Theme.controlStroke, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(HoldemAccessibility.Table.heroSeat)
        .turnClockAccessibilityValue(
            startedAt: turnStart,
            duration: context.state.turnDuration
        )
    }

    private var usesAccessibleLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var turnStart: Date? {
        context.state.isCurrentPlayer(at: context.heroIndex)
            ? context.state.turnStartedAt
            : nil
    }

    private var accessibilityLabel: String {
        var parts = [context.hero.name, "your seat", "stack \(ChipText.string(context.hero.stack))"]
        if let handName = context.heroHandName { parts.append(handName) }
        if context.hero.status != .active {
            parts.append(context.hero.status.spokenDescription)
        }
        if turnStart != nil {
            parts.append("your turn")
        }
        return parts.joined(separator: ", ")
    }
}

/// The hero's two cards with one combined VoiceOver description.
struct HoleCardsView: View {
    let cards: [Card]
    var highlight: Set<Card>? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                let card = cards.indices.contains(index) ? cards[index] : nil
                PlayingCardView(card: card,
                                width: Theme.Metrics.holeCardWidth,
                                height: Theme.Metrics.holeCardHeight,
                                dimmed: card.map(isDimmed) ?? false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(HoldemAccessibility.Table.holeCards)
    }

    var accessibilityLabel: String {
        var label = "Your hole cards"
        if cards.count >= 2 {
            label += ": \(cards.prefix(2).map(\.spokenDescription).joined(separator: ", "))"
        } else {
            label += ": not dealt"
        }
        return label
    }

    private func isDimmed(_ card: Card) -> Bool {
        guard let highlight else { return false }
        return !highlight.contains(card)
    }
}
