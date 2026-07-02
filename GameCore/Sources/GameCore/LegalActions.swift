/// What the current player is legally allowed to do. This is the betting-round
/// contract consumed by the UI action bar.
public struct LegalActions: Sendable, Equatable {
    public static let empty = LegalActions(
        canFold: false,
        canCheck: false,
        canCall: false,
        callAmount: 0,
        currentBet: 0,
        canRaise: false,
        minRaiseTo: 0,
        maxRaiseTo: 0
    )

    public var canFold: Bool
    public var canCheck: Bool
    public var canCall: Bool
    /// Additional chips needed to call (capped at the player's stack).
    public var callAmount: Int
    /// The current bet level this player must match before raising.
    public var currentBet: Int
    public var canRaise: Bool
    /// Smallest legal raise-to total.
    public var minRaiseTo: Int
    /// Largest raise-to total (the player's all-in).
    public var maxRaiseTo: Int

    public var hasAvailableAction: Bool {
        canFold || canCheck || canCall || canRaise
    }

    func allows(_ action: PlayerAction) -> Bool {
        switch action {
        case .fold:
            canFold
        case .check:
            canCheck
        case .call:
            canCall
        case .raise(let total):
            canRaise && total >= minRaiseTo && total <= maxRaiseTo
        }
    }
}
