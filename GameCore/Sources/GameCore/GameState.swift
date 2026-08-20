import Foundation

public enum Street: Int, Codable, Sendable {
    case preflop, flop, turn, river, showdown

    var boardCount: Int {
        switch self {
        case .preflop: 0
        case .flop: 3
        case .turn: 4
        case .river, .showdown: 5
        }
    }
}

/// The outcome for one player at the end of a hand.
public struct HandResult: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case playerID, amountWon, handName, bestFive
    }

    public internal(set) var playerID: String
    var amountWon: Int
    public internal(set) var handName: String?
    public internal(set) var bestFive: [Card]?

    init(playerID: String, amountWon: Int, handName: String?, bestFive: [Card]?) {
        self.playerID = playerID
        self.amountWon = amountWon
        self.handName = handName
        self.bestFive = bestFive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bestFive = try container.decodeIfPresent([Card].self, forKey: .bestFive)
        if let bestFive, bestFive.count != 5 || Set(bestFive).count != 5 {
            throw DecodingError.dataCorruptedError(
                forKey: .bestFive,
                in: container,
                debugDescription: "Best-five cards must contain five unique cards"
            )
        }
        self.init(
            playerID: try Identity.decoded(
                container.decode(String.self, forKey: .playerID),
                error: "Participant identity cannot be blank",
                codingPath: container.codingPath + [CodingKeys.playerID]
            ),
            amountWon: TableRules.table(try container.decode(Int.self, forKey: .amountWon)),
            handName: try container.decodeIfPresent(String.self, forKey: .handName),
            bestFive: bestFive
        )
    }
}

/// The complete, serializable state of a poker hand. This is the single object
/// that travels in the iMessage payload; every client renders from it.
public struct GameState: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey {
        case tableID, handNumber, players, dealerIndex
        case smallBlind, bigBlind, board, deck, pot, street, currentToAct, minRaise
        case turnStartedAt, turnDuration, results, version
    }

    public internal(set) var tableID: String
    public internal(set) var handNumber: Int
    public internal(set) var players: [Player]
    var dealerIndex: Int
    var smallBlind: Int
    public internal(set) var bigBlind: Int
    public internal(set) var board: [Card]
    /// Undealt cards, in order. Stored in the payload so any client can deal the
    /// next street deterministically. (Honest-client model: technically visible
    /// to anyone inspecting the payload — acceptable for casual play.)
    var deck: [Card]
    var street: Street
    /// Index into `players` of who must act, or nil between hands / at showdown.
    var currentToAct: Int?
    /// Minimum legal raise increment for the current round.
    var minRaise: Int
    /// When the current player's turn began (for lazy timeout resolution).
    public internal(set) var turnStartedAt: Date?
    public internal(set) var turnDuration: TimeInterval
    public internal(set) var results: [HandResult]?
    /// Monotonic version; lets clients ignore stale/older state.
    public internal(set) var version: Int
}

extension GameState {
    public func playerIndex(id: String) -> Int? {
        players.firstIndex { $0.id == id }
    }

    func player(id: String) -> Player? {
        playerIndex(id: id).map { players[$0] }
    }

    public func isCurrentPlayer(at index: Int) -> Bool {
        currentToAct == index && players.indices.contains(index)
    }

    public var currentPlayer: Player? {
        guard let currentToAct, players.indices.contains(currentToAct) else { return nil }
        return players[currentToAct]
    }

    public func currentHandName(for index: Int) -> String? {
        guard players.indices.contains(index) else { return nil }
        return HandEvaluator.evaluateIfPossible(players[index].holeCards + board)?.name
    }

    var dealerSeatIndex: Int? {
        players.isEmpty ? nil : Self.normalizedSeat(dealerIndex, playerCount: players.count)
    }

    public func isDealer(at index: Int) -> Bool {
        dealerSeatIndex == index
    }

    static func normalizedSeat(_ index: Int, playerCount: Int) -> Int {
        guard playerCount > 0 else { return 0 }
        return ((index % playerCount) + playerCount) % playerCount
    }

    /// The amount every active player must match in this betting round.
    var currentBet: Int {
        contenders.map(\.bet).max() ?? 0
    }

    /// Total chips in play, including live bets or completed-hand awards.
    public var displayPot: Int {
        if let results {
            return results.reduce(0) {
                TableRules.adding($0, $1.amountWon, limit: TableRules.tableMaximum)
            }
        }
        return players.reduce(0) {
            TableRules.adding($0, $1.committed, limit: TableRules.tableMaximum)
        }
    }

    /// Players still contesting the pot.
    var contenders: [Player] {
        players.filter(\.isContesting)
    }

    /// Players who remain seated and funded for another hand.
    public var playersEligibleForNextHand: [Player] {
        players.filter(\.isEligibleForNextHand)
    }

    /// Whether the current hand has produced a terminal result.
    public var isHandComplete: Bool { results != nil }

    /// The single remaining player, if the game is over.
    public var overallWinner: Player? {
        guard isHandComplete else { return nil }
        let eligible = playersEligibleForNextHand
        return eligible.count == 1 ? eligible.first : nil
    }

    /// Whether the table has a single remaining funded player and no more hands can be dealt.
    public var isGameOver: Bool {
        overallWinner != nil
    }

    /// Whether this participant is allowed to advance a completed table to the next hand.
    public func canDealNextHand(actorID: String) -> Bool {
        guard isHandComplete, !isGameOver, let player = player(id: actorID) else { return false }
        return player.isEligibleForNextHand
    }

    func nextSeat(after index: Int, where predicate: (Player) -> Bool) -> Int? {
        guard !players.isEmpty else { return nil }
        let start = Self.normalizedSeat(index, playerCount: players.count)
        for offset in 1...players.count {
            let candidate = (start + offset) % players.count
            if predicate(players[candidate]) { return candidate }
        }
        return nil
    }
}
