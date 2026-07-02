import SwiftUI
import GameCore

/// The full poker table, driven entirely by a `GameState` plus the id of the
/// viewer ("hero"). This is exactly what the iMessage view controller hands in.
public struct PokerTableView: View {
    public let state: GameState
    public let heroID: String
    public var now: Date = Date()
    public var onAction: (PlayerAction) -> Void = { _ in }
    /// When set, a "Deal next hand" button is shown once the hand is over.
    public var onDealNext: (() -> Void)? = nil
    /// When set, shows a "Leave" control; the player forfeits and exits the table.
    public var onLeave: (() -> Void)? = nil

    public init(state: GameState, heroID: String, now: Date = Date(),
                onAction: @escaping (PlayerAction) -> Void = { _ in },
                onDealNext: (() -> Void)? = nil,
                onLeave: (() -> Void)? = nil) {
        self.state = state
        self.heroID = heroID
        self.now = now
        self.onAction = onAction
        self.onDealNext = onDealNext
        self.onLeave = onLeave
    }

    private var presentation: PokerTablePresentation {
        PokerTablePresentation(state: state, heroID: heroID, canDealNext: onDealNext != nil)
    }

    private var canLeaveTable: Bool {
        !state.isGameOver
    }

    public var body: some View {
        VStack(spacing: 0) {
            PokerTableSeatsRow(state: state, presentation: presentation)
                .padding(.top, 12)

            Spacer(minLength: 16)

            BoardView(board: state.board,
                      pot: state.displayPot,
                      winningCards: presentation.winningCards,
                      handLabel: presentation.showdownHandLabel)
                .padding(.horizontal, 20)

            Spacer(minLength: 16)

            PokerTableBottomControls(
                state: state,
                presentation: presentation,
                onAction: onAction,
                onFold: { onAction(.fold) },
                onDealNext: onDealNext
            )
            .padding(.horizontal, 20)

            HeroHandDock(
                presentation: presentation,
                turnStartedAt: state.turnStartedAt,
                turnDuration: state.turnDuration,
                onFold: { onAction(.fold) }
            )
                .padding(.horizontal, 20)
                .padding(.top, 16)
        }
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .overlay(alignment: .topLeading) {
            if let onLeave, canLeaveTable {
                LeaveTableButton(action: onLeave)
            }
        }
        // One cubic-bezier curve drives every change: cards, chips, stacks,
        // and the action-area cross-fade.
        .animation(.tableSnap, value: state.version)
        .animation(.tableSnap, value: presentation.actionMode)
    }
}
