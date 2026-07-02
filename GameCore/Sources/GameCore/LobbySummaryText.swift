extension Lobby {
    var summaryText: String {
        "Lobby · \(seats.count)/\(maxPlayers) joined · \(readyCount) ready"
    }
}
