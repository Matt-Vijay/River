import Foundation

/// A raise amount is the player's new total commitment for this betting round.
public enum PlayerAction: Codable, Sendable, Equatable {
    case fold
    case check
    case call
    case raise(to: Int)
}

/// The betting-round contract consumed by the UI action bar.
public struct LegalActions: Sendable, Equatable {
    static let empty = LegalActions(
        canFold: false,
        callAmount: 0,
        currentBet: 0,
        raiseBounds: nil
    )

    public let canFold: Bool
    public let callAmount: Int
    public let currentBet: Int
    public let raiseBounds: ClosedRange<Int>?

    public var canCheck: Bool { canFold && callAmount == 0 }
    public var canCall: Bool { canFold && callAmount > 0 }

    func allows(_ action: PlayerAction) -> Bool {
        switch action {
        case .fold: canFold
        case .check: canCheck
        case .call: canCall
        case .raise(let total): raiseBounds?.contains(total) == true
        }
    }
}

extension GameState {
    public func legalActions(for index: Int) -> LegalActions {
        guard !isHandComplete, isCurrentPlayer(at: index) else { return .empty }

        let player = players[index]
        guard player.canAct else { return .empty }

        let toCall = max(0, currentBet - player.bet)
        let callAmount = min(toCall, player.stack)
        let raiseBounds = raiseBounds(for: player, toCall: toCall)

        return LegalActions(
            canFold: true,
            callAmount: callAmount,
            currentBet: currentBet,
            raiseBounds: raiseBounds
        )
    }

    private func raiseBounds(for player: Player, toCall: Int) -> ClosedRange<Int>? {
        let maxRaiseTo = TableRules.adding(
            player.bet,
            player.stack,
            limit: TableRules.tableMaximum
        )
        let actionReopened = player.lastActionBet
            .map { max(0, currentBet - $0) >= minRaise }
            ?? true
        guard actionReopened, maxRaiseTo > currentBet, player.stack > toCall else { return nil }
        let minRaiseTo = min(
            TableRules.adding(currentBet, minRaise, limit: TableRules.tableMaximum),
            maxRaiseTo
        )
        return minRaiseTo...maxRaiseTo
    }

    func applying(_ kind: TableOperation, actorID: String, now: Date) -> TableOperationResult {
        switch kind {
        case .gameAction(let action): return applyingGameAction(action, actorID: actorID, now: now)

        case .resolveTimeout: return applyingTimeoutResolution(actorID: actorID, now: now)

        case .joinGame(let name, let avatar, let startingStack):
            return joiningGame(
                actorID: actorID, name: name, avatar: avatar, startingStack: startingStack)

        case .leaveGame: return leavingGame(actorID: actorID, now: now)

        case .dealNextHand(let seed): return dealingNextHand(seed: seed, actorID: actorID, now: now)

        default: return .rejected(.wrongPhase)
        }
    }

    private func applyingGameAction(_ action: PlayerAction, actorID: String, now: Date)
        -> TableOperationResult
    {
        guard !isGameOver else { return .rejected(.gameOver) }
        guard let actorIndex = playerIndex(id: actorID) else { return .rejected(.notSeated) }
        guard !isTurnExpired(at: now) else { return .rejected(.illegalAction) }
        guard isCurrentPlayer(at: actorIndex) else { return .rejected(.notActorTurn) }

        var next = self
        guard next.applyCurrent(action, by: actorIndex, now: now) else {
            return .rejected(.illegalAction)
        }
        return .applied(.game(next))
    }

    private func applyingTimeoutResolution(actorID: String, now: Date) -> TableOperationResult {
        guard !isGameOver else { return .rejected(.gameOver) }
        guard let actor = player(id: actorID), !actor.hasLeft else { return .rejected(.notSeated) }
        var next = self
        guard next.resolveTimeout(now: now) else { return .rejected(.illegalAction) }
        return .applied(.game(next))
    }

    private func joiningGame(actorID: String, name: String, avatar: String, startingStack: Int)
        -> TableOperationResult
    {
        guard !isGameOver else { return .rejected(.gameOver) }
        guard canJoinGame(id: actorID) else { return .rejected(.tableFull) }

        var next = self
        guard next.rejoinOrAddSittingOutPlayer(
            id: actorID, name: name, avatar: avatar, stack: startingStack)
        else { return .unchanged }
        guard let nextVersion = MonotonicCounter.successor(of: version) else {
            return .rejected(.illegalAction)
        }

        next.version = nextVersion
        return .applied(.game(next))
    }

    private func leavingGame(actorID: String, now: Date) -> TableOperationResult {
        guard !isGameOver else { return .rejected(.gameOver) }
        guard let player = player(id: actorID), !player.hasLeft else {
            return .rejected(.notSeated)
        }

        var next = self
        guard next.playerLeaves(id: actorID, now: now) else { return .rejected(.illegalAction) }
        return .applied(.game(next))
    }

    private func dealingNextHand(seed: UInt64, actorID: String, now: Date) -> TableOperationResult {
        guard playersEligibleForNextHand.count >= 2 else { return .rejected(.gameOver) }
        guard let actor = player(id: actorID), actor.isEligibleForNextHand else {
            return .rejected(.notSeated)
        }
        guard isHandComplete else { return .rejected(.illegalAction) }
        guard let next = startNextHand(seed: seed, now: now) else { return .rejected(.gameOver) }
        return .applied(.game(next))
    }

    public func canJoinGame(id: String) -> Bool {
        !isGameOver && (playerIndex(id: id) != nil || players.count < TableRules.maxPlayers)
    }

    @discardableResult
    mutating func rejoinOrAddSittingOutPlayer(
        id: String, name: String, avatar: String, stack: Int
    ) -> Bool {
        if let index = playerIndex(id: id) {
            guard players[index].hasLeft
                || (isHandComplete && players[index].stack == 0) else { return false }
            players[index].name = ProfileText.name(name)
            players[index].avatar = ProfileText.avatar(avatar)
            players[index].hasLeft = false

            // Rejoining schedules a dealt player for the next hand without
            // changing this hand's fold/all-in or side-pot state.
            if !isHandComplete && players[index].holeCards.count == 2 {
                return true
            }

            players[index].status = .sittingOut
            if players[index].stack <= 0 {
                players[index].stack = TableRules.normalizedStartingStack(stack)
            }
            return true
        }

        guard players.count < TableRules.maxPlayers else { return false }
        var player = Player(id: id, name: name, avatar: avatar,
                            stack: TableRules.normalizedStartingStack(stack))
        player.status = .sittingOut
        players.append(player)
        return true
    }

    @discardableResult
    mutating func applyCurrent(_ action: PlayerAction, by index: Int, now: Date) -> Bool {
        guard legalActions(for: index).allows(action) else { return false }
        guard let nextVersion = MonotonicCounter.successor(of: version) else { return false }

        let previousBet = currentBet
        switch action {
        case .fold:
            players[index].status = .folded
        case .check:
            break
        case .call:
            pay(index, additional: previousBet - players[index].bet)
        case .raise(let total):
            pay(index, additional: total - players[index].bet)
            minRaise = max(minRaise, total - previousBet)
        }
        players[index].lastActionBet = players[index].bet
        players[index].lastAction = action

        version = nextVersion
        advance(now: now)
        return true
    }

    mutating func pay(_ index: Int, additional: Int) {
        guard additional > 0 else { return }
        let amount = min(additional, players[index].stack)
        players[index].stack -= amount
        players[index].bet += amount
        players[index].committed += amount
        if players[index].stack == 0 { players[index].status = .allIn }
    }

    /// Excludes a player from future deals, folding a live hand when needed.
    @discardableResult
    mutating func playerLeaves(id: String, now: Date = Date()) -> Bool {
        guard !isGameOver,
              let index = playerIndex(id: id),
              !players[index].hasLeft,
              let nextVersion = MonotonicCounter.successor(of: version),
              isHandComplete || contenders.count >= 2 else { return false }
        players[index].hasLeft = true
        version = nextVersion
        guard !isHandComplete,
              players[index].canAct else { return true }

        players[index].status = .folded
        players[index].lastActionBet = players[index].bet
        players[index].lastAction = .fold
        if isCurrentPlayer(at: index) {
            advance(now: now)
        } else if contenders.count <= 1 {
            awardUncontested()
        }
        return true
    }
}
