import GameCore

extension PokerTablePresentation {
    var heroIndex: Int? {
        state.playerIndex(id: heroID)
    }

    var hero: Player? {
        heroIndex.flatMap { state.player(at: $0) }
    }

    var isHeroTurn: Bool {
        heroIndex.map { state.isCurrentPlayer(at: $0) } ?? false
    }

    var opponents: [(index: Int, player: Player)] {
        guard let heroIndex else {
            return Array(state.players.enumerated()).map { ($0.offset, $0.element) }
        }

        return (1..<state.players.count).compactMap { offset in
            let index = (heroIndex + offset) % state.players.count
            return state.player(at: index).map { (index, $0) }
        }
    }

    var heroHandName: String? {
        guard let heroIndex, let hero, hero.isContesting else { return nil }
        return state.currentHandRank(for: heroIndex)?.name
    }
}
