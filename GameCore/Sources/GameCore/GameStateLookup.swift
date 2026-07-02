public extension GameState {
    func playerIndex(id: String) -> Int? {
        players.firstIndex { $0.id == id }
    }

    func player(at index: Int) -> Player? {
        guard players.indices.contains(index) else { return nil }
        return players[index]
    }

    func player(id: String) -> Player? {
        playerIndex(id: id).flatMap { player(at: $0) }
    }

    func containsPlayer(id: String) -> Bool {
        playerIndex(id: id) != nil
    }

    func isCurrentPlayer(at index: Int) -> Bool {
        currentToAct == index && players.indices.contains(index)
    }

    var currentPlayer: Player? {
        guard let index = currentToAct else { return nil }
        return player(at: index)
    }
}
