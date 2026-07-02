import Foundation

/// The complete, serializable state of a poker hand. This is the single object
/// that travels in the iMessage payload; every client renders from it.
public struct GameState: Sendable, Equatable {
    public var tableID: String
    public var appliedOperationIDs: [String]
    public var handNumber: Int
    public var players: [Player]
    public var dealerIndex: Int
    public var smallBlind: Int
    public var bigBlind: Int
    public var board: [Card]
    /// Undealt cards, in order. Stored in the payload so any client can deal the
    /// next street deterministically. (Honest-client model: technically visible
    /// to anyone inspecting the payload — acceptable for casual play.)
    public var deck: [Card]
    /// Chips collected from completed betting rounds.
    public var pot: Int
    public var street: Street
    /// Index into `players` of who must act, or nil between hands / at showdown.
    public var currentToAct: Int?
    /// The bet amount to match in the current round.
    public var currentBet: Int
    /// Minimum legal raise increment for the current round.
    public var minRaise: Int
    /// When the current player's turn began (for lazy timeout resolution).
    public var turnStartedAt: Date?
    public var turnDuration: TimeInterval
    public var results: [HandResult]?
    /// Monotonic version; lets clients ignore stale/older state.
    public var version: Int

    public init(tableID: String = UUID().uuidString, appliedOperationIDs: [String] = [],
                handNumber: Int, players: [Player],
                dealerIndex: Int, smallBlind: Int, bigBlind: Int, board: [Card],
                deck: [Card], pot: Int, street: Street, currentToAct: Int?,
                currentBet: Int, minRaise: Int, turnStartedAt: Date?,
                turnDuration: TimeInterval, results: [HandResult]?, version: Int) {
        let isHandComplete = results != nil
        let players = Self.normalizedVisibleCards(
            in: Self.normalizedPlayers(players, isHandComplete: isHandComplete)
        )
        let board = Self.normalizedBoard(board, players: players)
        let currentToAct = Self.normalizedCurrentActor(currentToAct, players: players, isHandComplete: isHandComplete)
        self.tableID = TableIdentity.normalized(tableID)
        self.appliedOperationIDs = OperationIdentity.history(appliedOperationIDs)
        self.handNumber = max(1, handNumber)
        self.players = players
        self.dealerIndex = Self.normalizedSeat(dealerIndex, playerCount: players.count)
        let blinds = BlindStructure.normalized(smallBlind: smallBlind, bigBlind: bigBlind)
        self.smallBlind = blinds.smallBlind
        self.bigBlind = blinds.bigBlind
        self.board = board
        self.deck = Self.normalizedDeck(deck, players: players, board: board)
        self.pot = Self.normalizedPot(pot, isHandComplete: isHandComplete)
        self.street = Self.normalizedStreet(street, isHandComplete: isHandComplete)
        self.currentToAct = currentToAct
        self.currentBet = Self.normalizedCurrentBet(currentBet, players: players, isHandComplete: isHandComplete)
        self.minRaise = isHandComplete ? 0 : max(blinds.bigBlind, minRaise)
        self.turnStartedAt = currentToAct == nil ? nil : turnStartedAt
        self.turnDuration = TurnClock.normalized(turnDuration)
        self.results = Self.normalizedResults(results, players: players, board: board)
        self.version = max(0, version)
    }
}

extension GameState {
    static func normalizedPlayers(_ players: [Player], isHandComplete: Bool) -> [Player] {
        ParticipantIdentity.uniquePlayers(players).map { player in
            var copy = player
            copy.holeCards = Array(copy.holeCards.prefix(2))
            if isHandComplete {
                copy.bet = 0
                copy.hasActed = false
            }
            if copy.hasLeft && copy.isContesting && !isHandComplete {
                copy.status = .folded
                copy.hasActed = true
                copy.lastAction = .fold
            }
            return copy
        }
    }

    static func normalizedVisibleCards(in players: [Player]) -> [Player] {
        var seen = Set<Card>()
        return players.map { player in
            var copy = player
            copy.holeCards = copy.holeCards.filter { seen.insert($0).inserted }
            return copy
        }
    }

    static func normalizedBoard(_ board: [Card], players: [Player] = []) -> [Card] {
        var seen = Set(players.flatMap(\.holeCards))
        return Array(board.filter { seen.insert($0).inserted }.prefix(5))
    }

    static func normalizedDeck(_ deck: [Card], players: [Player], board: [Card]) -> [Card] {
        var seen = Set(board)
        players.flatMap(\.holeCards).forEach { seen.insert($0) }
        return deck.filter { seen.insert($0).inserted }
    }

    static func normalizedStreet(_ street: Street, isHandComplete: Bool) -> Street {
        isHandComplete ? .showdown : street
    }

    static func normalizedPot(_ pot: Int, isHandComplete: Bool) -> Int {
        isHandComplete ? 0 : max(0, pot)
    }

    static func normalizedCurrentBet(_ currentBet: Int, players: [Player], isHandComplete: Bool) -> Int {
        guard !isHandComplete else { return 0 }
        let highestPlayerBet = players.map(\.bet).max() ?? 0
        return max(0, currentBet, highestPlayerBet)
    }

    static func normalizedCurrentActor(_ index: Int?, players: [Player], isHandComplete: Bool) -> Int? {
        guard !isHandComplete, let index, players.indices.contains(index), players[index].canAct else {
            return nil
        }
        return index
    }

    static func normalizedResults(_ results: [HandResult]?, players: [Player], board: [Card]) -> [HandResult]? {
        guard let results else { return nil }
        let playerIDs = Set(players.map(\.id))
        let visibleCards = Set(board + players.flatMap(\.holeCards))
        var order: [String] = []
        var merged: [String: HandResult] = [:]
        for result in results {
            guard playerIDs.contains(result.playerID) else { continue }
            var copy = result
            copy.amountWon = max(0, copy.amountWon)
            if let bestFive = copy.bestFive, Set(bestFive).count != 5 || !Set(bestFive).isSubset(of: visibleCards) {
                copy.bestFive = nil
            }

            if var existing = merged[copy.playerID] {
                existing.amountWon += copy.amountWon
                merged[copy.playerID] = existing
            } else {
                order.append(copy.playerID)
                merged[copy.playerID] = copy
            }
        }
        let normalized = order.compactMap { merged[$0] }
        return normalized.isEmpty ? nil : normalized
    }
}
