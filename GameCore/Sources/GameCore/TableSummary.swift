public extension GamePayload {
    static func summary(for message: TableMessage) -> String {
        switch message {
        case .lobby(let lobby):
            return lobby.summaryText
        case .game(let state):
            return summary(for: state)
        }
    }

    /// Caption shown on the collapsed message bubble in the transcript.
    static func summary(for state: GameState) -> String {
        if let winner = state.overallWinner {
            return "\(SummaryNameText.string(winner.name)) wins the game"
        }

        if let results = state.results, !results.isEmpty {
            return state.resultSummaryText(results: results)
        }

        return state.liveSummaryText
    }
}
