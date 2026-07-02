import SwiftUI
import GameCore

struct PokerTableActionArea: View {
    let state: GameState
    let presentation: PokerTablePresentation
    let onAction: (PlayerAction) -> Void
    let onFold: () -> Void
    var onDealNext: (() -> Void)?

    var body: some View {
        content
            .id(presentation.actionMode)
            .transition(.opacity)
    }

    @ViewBuilder
    private var content: some View {
        if let winner = gameWinner {
            ResultBanner(text: "\(winner.name) wins game")
        } else if let onDealNext, presentation.canHeroDealNext {
            VStack(spacing: 10) {
                if let handWinner {
                    ResultBanner(text: "\(handWinner.name) wins hand")
                }

                Button(action: onDealNext) {
                    Text("Deal next hand")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .stableOneLineText(minScale: 0.82)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Metrics.actionControlHeight)
                        .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(.white))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(HoldemAccessibility.Table.dealNext)
            }
        } else if let handWinner {
            ResultBanner(text: "\(handWinner.name) wins hand")
        } else if let legal = presentation.legalActionsForHero() {
            ActionBarView(
                legal: legal,
                bigBlind: state.bigBlind,
                pot: state.displayPot,
                onFold: onFold,
                onCheck: { onAction(.check) },
                onCall: { onAction(.call) },
                onRaise: { onAction(.raise(to: $0)) }
            )
        } else {
            WaitingBar(text: presentation.waitingText)
        }
    }

    private var gameWinner: Player? {
        guard state.isHandComplete else { return nil }
        return state.overallWinner
    }

    private var handWinner: Player? {
        guard state.isHandComplete,
              let winnerID = state.results?
                .filter({ $0.amountWon > 0 })
                .max(by: { $0.amountWon < $1.amountWon })?
                .playerID else {
            return nil
        }
        return state.player(id: winnerID)
    }

}

private struct ResultBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "trophy.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Theme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .allowsTightening(true)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Metrics.actionControlHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityIdentifier(HoldemAccessibility.Table.result)
    }
}
