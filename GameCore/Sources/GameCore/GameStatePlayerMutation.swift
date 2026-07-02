extension GameState {
    mutating func rejoinOrAddSittingOutPlayer(id: String, name: String, avatar: String, stack: Int) -> Bool {
        if let index = playerIndex(id: id) {
            guard players[index].hasLeft else { return true }
            players[index].hasLeft = false
            players[index].status = .sittingOut
            if players[index].stack <= 0 {
                players[index].stack = StartingStack.normalized(stack)
            }
            return true
        }

        guard players.count < TableSize.maxPlayers else { return false }
        var player = Player(id: id, name: name, avatar: avatar, stack: StartingStack.normalized(stack))
        player.status = .sittingOut
        players.append(player)
        return true
    }
}
