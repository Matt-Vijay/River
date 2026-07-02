import SwiftUI
import GameCore

struct HeroHandDock: View {
    let presentation: PokerTablePresentation
    let turnStartedAt: Date?
    let turnDuration: TimeInterval
    let onFold: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            HoleCardsView(
                cards: presentation.hero?.holeCards ?? [],
                highlight: presentation.winningCards,
                onFold: presentation.canHeroFold ? onFold : nil
            )
            HandStrengthBox(
                name: presentation.hero?.name ?? "Player",
                avatar: presentation.hero?.avatar ?? "🙂",
                stack: presentation.hero?.stack ?? 0,
                handName: presentation.heroHandName,
                turnStart: presentation.isHeroTurn ? turnStartedAt : nil,
                turnDuration: turnDuration,
                highlightWin: presentation.hero.map { presentation.didWin($0) } ?? false
            )
        }
        .frame(maxWidth: .infinity)
    }
}
