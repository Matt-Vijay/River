import SwiftUI
import GameCore

struct PokerTableBottomControls: View {
    let state: GameState
    let presentation: PokerTablePresentation
    let onAction: (PlayerAction) -> Void
    let onFold: () -> Void
    let onDealNext: (() -> Void)?

    var body: some View {
        // Chip + controls live in a fixed-height region anchored to the bottom,
        // so the raise panel grows upward into reserved space and the hole cards
        // never move. The chip sits 10pt above the controls.
        VStack(spacing: 10) {
            ZStack {
                if let hero = presentation.hero, hero.bet > 0 {
                    BetChip(amount: hero.bet).transition(.opacity)
                }
            }
            .frame(height: 30)

            PokerTableActionArea(
                state: state,
                presentation: presentation,
                onAction: onAction,
                onFold: onFold,
                onDealNext: onDealNext
            )
        }
        .frame(height: 150, alignment: .bottom)
    }
}
