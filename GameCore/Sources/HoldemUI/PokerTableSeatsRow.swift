import SwiftUI
import GameCore

struct PokerTableSeatsRow: View {
    let state: GameState
    let presentation: PokerTablePresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            seats.frame(maxWidth: .infinity)
            ScrollView(.horizontal, showsIndicators: false) { seats }
        }
        .frame(height: 185, alignment: .top)
    }

    private var seats: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(presentation.opponents, id: \.index) { entry in
                PlayerSeatView(
                    player: entry.player,
                    isDealer: state.isDealer(at: entry.index),
                    isActive: state.isCurrentPlayer(at: entry.index),
                    turnStartedAt: state.isCurrentPlayer(at: entry.index) ? state.turnStartedAt : nil,
                    turnDuration: state.turnDuration,
                    lastActionLabel: presentation.lastActionLabel(for: entry.player),
                    highlightWin: presentation.didWin(entry.player),
                    revealCards: presentation.revealedCards(for: entry.player),
                    highlight: presentation.winningCards
                )
            }
        }
        .padding(.horizontal, 8)
    }
}
