extension GameState {
    mutating func pay(_ index: Int, additional: Int) {
        guard additional > 0 else { return }
        let amount = min(additional, players[index].stack)
        players[index].stack -= amount
        players[index].bet += amount
        players[index].committed += amount
        if players[index].stack == 0 { players[index].status = .allIn }
    }
}
