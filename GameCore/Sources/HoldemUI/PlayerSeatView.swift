import SwiftUI
import GameCore

/// One opponent at the top of the table: avatar, name, stack, dealer button,
/// current bet chip, and either a countdown ring (when active) or their last
/// action label.
public struct PlayerSeatView: View {
    let player: Player
    var isDealer: Bool = false
    var isActive: Bool = false
    /// When the active player's turn began; drives the live countdown pie.
    var turnStartedAt: Date? = nil
    var turnDuration: TimeInterval = TurnClock.defaultDuration
    var lastActionLabel: String? = nil
    /// Flash the stack green when the player just won chips.
    var highlightWin: Bool = false
    /// Hole cards to reveal at showdown (nil = keep hidden).
    var revealCards: [Card]? = nil
    /// Winning cards to keep bright; revealed cards outside this set are dimmed.
    var highlight: Set<Card>? = nil

    public init(player: Player, isDealer: Bool = false, isActive: Bool = false,
                turnStartedAt: Date? = nil, turnDuration: TimeInterval = TurnClock.defaultDuration,
                lastActionLabel: String? = nil, highlightWin: Bool = false,
                revealCards: [Card]? = nil, highlight: Set<Card>? = nil) {
        self.player = player
        self.isDealer = isDealer
        self.isActive = isActive
        self.turnStartedAt = turnStartedAt
        self.turnDuration = turnDuration
        self.lastActionLabel = lastActionLabel
        self.highlightWin = highlightWin
        self.revealCards = revealCards
        self.highlight = highlight
    }

    private var isFolded: Bool { player.status == .folded }

    public var body: some View {
        VStack(spacing: 4) {
            PlayerSeatMarker(
                isActive: isActive,
                turnStartedAt: turnStartedAt,
                turnDuration: turnDuration,
                lastActionLabel: lastActionLabel
            )
                .frame(height: 18)

            PlayerSeatAvatar(avatar: player.avatar, isDealer: isDealer)

            Text(player.name)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(ChipFormatter.string(player.stack))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(highlightWin ? Theme.accent : .white)
                .contentTransition(.numericText())

            // Reserve the chip's space always, so seats don't change height
            // (and shift the row) when bets appear or clear.
            ZStack {
                if player.bet > 0 {
                    BetChip(amount: player.bet).transition(.opacity)
                }
            }
            .frame(height: 24)

            // Reserve the reveal slot always so seats keep a constant height;
            // the cards only appear at showdown.
            PlayerSeatCardReveal(cards: revealCards, highlight: highlight)
            .frame(height: 37)
            .padding(.top, 2)
        }
        .frame(width: 66)
        .opacity(isFolded ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .animation(.tableSnap, value: isFolded)
    }

    private var accessibilityLabel: String {
        var parts = [player.name]
        if isDealer { parts.append("dealer") }
        parts.append("stack \(ChipFormatter.string(player.stack))")
        if highlightWin { parts.append("winner") }
        if player.bet > 0 { parts.append("bet \(ChipFormatter.string(player.bet))") }
        parts.append(statusLabel)
        if let revealCards, revealCards.count >= 2 {
            parts.append("cards \(revealCards.map(\.description).joined(separator: " "))")
        }
        if isActive {
            parts.append("to act")
            parts.append("\(Int(TurnClock.normalized(turnDuration))) second clock")
        }
        if let lastActionLabel { parts.append(lastActionLabel) }
        return parts.joined(separator: ", ")
    }

    private var statusLabel: String {
        switch player.status {
        case .active:
            "active"
        case .folded:
            "folded"
        case .allIn:
            "all in"
        case .sittingOut:
            "sitting out"
        case .eliminated:
            "eliminated"
        }
    }
}
