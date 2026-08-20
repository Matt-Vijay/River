import Testing
@testable import GameCore
@testable import HoldemUI

@Suite("Hole card accessibility")
@MainActor
struct HoleCardsAccessibilityTests {
    @Test("hole cards announce both card descriptions")
    func holeCardsAnnounceBothCardDescriptions() {
        let view = HoleCardsView(cards: [
            Card(rank: .ace, suit: .spades),
            Card(rank: .ten, suit: .hearts),
        ])

        #expect(view.accessibilityLabel == "Your hole cards: ace of spades, ten of hearts")
    }
}
