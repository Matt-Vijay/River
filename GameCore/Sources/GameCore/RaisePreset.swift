public enum RaisePreset: Sendable {
    case halfPot
    case pot
}

public extension LegalActions {
    func recommendedRaiseTo(_ preset: RaisePreset, pot: Int) -> Int {
        let raiseBase = pot + callAmount
        let raiseAmount: Int
        switch preset {
        case .halfPot:
            raiseAmount = raiseBase / 2
        case .pot:
            raiseAmount = raiseBase
        }
        return min(max(currentBet + raiseAmount, minRaiseTo), maxRaiseTo)
    }
}
