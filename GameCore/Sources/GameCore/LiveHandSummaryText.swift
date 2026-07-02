extension GameState {
    var liveSummaryText: String {
        let streetName = street.summaryName
        if let player = currentPlayer {
            return "\(streetName) · Pot \(ChipText.string(displayPot)) · \(SummaryNameText.string(player.name)) to act"
        }
        return "\(streetName) · Pot \(ChipText.string(displayPot))"
    }
}
