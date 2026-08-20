import SwiftUI
import GameCore

struct PokerTableSeatsRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let context: PokerTableContext

    var body: some View {
        ViewThatFits(in: .horizontal) {
            seats.frame(maxWidth: .infinity)
            ScrollView(.horizontal, showsIndicators: false) {
                seats
            }
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 240 : 185, alignment: .top)
    }

    private var seats: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(1..<context.state.players.count, id: \.self) { offset in
                PlayerSeatView(
                    index: (context.heroIndex + offset) % context.state.players.count,
                    context: context
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

/// One opponent at the top of the table: avatar, name, stack, dealer button,
/// current bet chip, and either a countdown ring (when active) or their last
/// action label.
private struct PlayerSeatView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let index: Int
    let context: PokerTableContext

    private var player: Player { context.state.players[index] }
    private var isDealer: Bool { context.state.isDealer(at: index) }
    private var isActive: Bool { context.state.isCurrentPlayer(at: index) }
    private var turnStartedAt: Date? { isActive ? context.state.turnStartedAt : nil }
    private var highlightWin: Bool { context.didWin(player) }
    private var revealCards: [Card]? { context.revealedCards(for: player) }

    var body: some View {
        VStack(spacing: 4) {
            marker.frame(height: usesAccessibleLayout ? 38 : 18)

            avatar

            Text(player.name)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(usesAccessibleLayout ? 2 : 1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(ChipText.string(player.stack))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(highlightWin ? Theme.accent : .white)

            // Reserve the chip's space always, so seats don't change height
            // (and shift the row) when bets appear or clear.
            ZStack {
                if player.bet > 0 {
                    BetChip(amount: player.bet)
                }
            }
            .frame(height: 24)

            // Reserve the reveal slot always so seats keep a constant height;
            // the cards only appear at showdown.
            cardReveal
                .frame(height: 37)
                .padding(.top, 2)
        }
        .frame(width: usesAccessibleLayout ? 140 : 66)
        .opacity(player.status == .folded ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .turnClockAccessibilityValue(
            startedAt: turnStartedAt,
            duration: context.state.turnDuration
        )
    }

    private var usesAccessibleLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var marker: some View {
        ZStack {
            Color.clear.frame(width: 1, height: 18)
            if let turnStartedAt {
                CountdownTimer(startedAt: turnStartedAt, duration: context.state.turnDuration)
                    .frame(width: 16, height: 16)
            } else if let label = context.lastActionLabel(for: player) {
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(player.avatar)
                .font(.system(size: 38))
                .frame(width: 50, height: 50)
            if isDealer {
                Text("D")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.white))
            }
        }
    }

    private var cardReveal: some View {
        ZStack {
            if let revealCards {
                HStack(spacing: 3) {
                    ForEach(revealCards.indices, id: \.self) { index in
                        PlayingCardView(
                            card: revealCards[index],
                            width: 25,
                            height: 35,
                            dimmed: context.winningCards?.contains(revealCards[index]) == false
                        )
                    }
                }
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [player.name]
        if isDealer { parts.append("dealer") }
        parts.append("stack \(ChipText.string(player.stack))")
        if highlightWin { parts.append("winner") }
        if player.bet > 0 { parts.append("bet \(ChipText.string(player.bet))") }
        parts.append(player.status.spokenDescription)
        if let revealCards {
            parts.append("cards \(revealCards.map(\.spokenDescription).joined(separator: ", "))")
        }
        if isActive {
            parts.append("to act")
        }
        if let label = context.lastActionLabel(for: player) { parts.append(label) }
        return parts.joined(separator: ", ")
    }

}
