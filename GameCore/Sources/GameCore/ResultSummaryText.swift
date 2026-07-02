extension GameState {
    func resultSummaryText(results: [HandResult]) -> String {
        let winners = results.filter { $0.amountWon > 0 }
        guard let top = winners.max(by: { $0.amountWon < $1.amountWon }),
              let topPlayer = player(id: top.playerID) else {
            return "Hand #\(handNumber) complete"
        }
        let tiedWinners = winners.filter { $0.amountWon == top.amountWon }
        if tiedWinners.count > 1 {
            let names = tiedWinners.compactMap { player(id: $0.playerID).map { SummaryNameText.string($0.name) } }
            if !names.isEmpty {
                return "\(Self.joinedNames(names)) split \(ChipText.string(top.amountWon))"
            }
        }

        if let hand = top.handName {
            return "\(SummaryNameText.string(topPlayer.name)) won \(ChipText.string(top.amountWon)) with a \(hand)"
        }
        return "\(SummaryNameText.string(topPlayer.name)) won \(ChipText.string(top.amountWon))"
    }

    private static func joinedNames(_ names: [String]) -> String {
        guard let first = names.first else { return "" }
        guard names.count > 1 else { return first }
        if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        }
        return "\(names.dropLast().joined(separator: ", ")), and \(names.last ?? "")"
    }
}
