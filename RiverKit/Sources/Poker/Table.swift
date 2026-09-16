import Foundation

public struct Profile: Codable, Equatable, Sendable {
    public let name: String
    public let avatar: String

    public init?(name: String, avatar: String) {
        let name = Self.boundedName(name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.rangeOfCharacter(from: .controlCharacters.union(.whitespacesAndNewlines).inverted) != nil,
              !avatar.isEmpty, avatar.utf8.count <= 64 else { return nil }
        self.name = name
        self.avatar = String(avatar.prefix(1))
    }

    public static func boundedName(_ text: String) -> String {
        let scalars = text.unicodeScalars.lazy
            // Joiners shape names and composed emoji; other controls stay excluded.
            .filter { $0 == "\u{200C}" || $0 == "\u{200D}" || !CharacterSet.controlCharacters.contains($0) }
            .drop(while: { CharacterSet.whitespacesAndNewlines.contains($0) }).prefix(96)
        var name = String(String.UnicodeScalarView(scalars))
        name = String(name.prefix(24))
        while name.utf8.count > 96 { name.removeLast() }
        return name
    }
}

public struct Rules: Codable, Equatable, Sendable {
    public static let standard = Rules()
    public internal(set) var capacity = 5
    public internal(set) var buyIn = 1_000
    public internal(set) var smallBlind = 5
    public internal(set) var bigBlind = 10
    public internal(set) var turnSeconds = 30
    static let chipLimit = 1_000_000_000_000
}

public struct Seat: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public internal(set) var profile: Profile
    public internal(set) var chips: Int
    public internal(set) var hasLeft = false
    public var isEligible: Bool { !hasLeft && chips > 0 }
}

public struct Hand: Codable, Equatable, Sendable {
    public enum Street: Int, Codable, CaseIterable, Sendable {
        case preflop, flop, turn, river
        public var cardCount: Int { [0, 3, 4, 5][rawValue] }
    }

    public struct Stake: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public internal(set) var bet = 0
        public internal(set) var committed = 0
        public internal(set) var folded = false
        public internal(set) var actedAtBet: Int?
        public internal(set) var lastAction: Bet?
    }

    public let number: Int
    public let dealerID: String
    public let deck: [Card]
    // Deal order starts left of the dealer. It also determines odd-chip priority.
    public internal(set) var stakes: [Stake]
    public internal(set) var street = Street.preflop
    public internal(set) var turn: String?
    public internal(set) var deadline: Int64?
    public internal(set) var raiseIncrement: Int
    public internal(set) var isComplete = false

    public var board: [Card] { Array(deck.dropFirst(stakes.count * 2).prefix(street.cardCount)) }
    public var pot: Int { stakes.reduce(0) { $0 + $1.committed } }
    public var bigBlindID: String { stakes[stakes.count == 2 ? 0 : 1].id }
    public var smallBlindID: String { stakes[stakes.count == 2 ? 1 : 0].id }
    public var contenders: [Stake] { stakes.filter { !$0.folded } }

    public func cards(for id: String) -> [Card] {
        guard let index = stakes.firstIndex(where: { $0.id == id }) else { return [] }
        return [deck[index], deck[index + stakes.count]]
    }

    public func remaining(at date: Date) -> TimeInterval {
        guard let deadline else { return 0 }
        return max(0, Double(deadline) / 1_000 - date.timeIntervalSince1970)
    }
}

public struct Table: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public internal(set) var version = 0
    public internal(set) var rules: Rules
    public internal(set) var seats: [Seat] = []
    public internal(set) var hand: Hand?

    public init(id: String = UUID().uuidString, rules: Rules = .standard) {
        self.id = id
        self.rules = rules
    }

    public var eligibleSeats: [Seat] { seats.filter(\.isEligible) }
    public var isFinished: Bool { hand?.isComplete == true && eligibleSeats.count < 2 }
    public var canDeal: Bool { (hand == nil || hand?.isComplete == true) && eligibleSeats.count >= 2 }
    public var isFull: Bool { seats.filter { !$0.hasLeft }.count >= rules.capacity }
    public var currentBet: Int {
        guard let hand, !hand.isComplete else { return 0 }
        let activeCount = hand.stakes.filter { !$0.folded && seat($0.id)?.isEligible == true }.count
        let stakes = activeCount == 1 ? hand.contenders : hand.stakes
        return max(hand.street == .preflop && activeCount > 1 ? rules.bigBlind : 0, stakes.map(\.bet).max() ?? 0)
    }
    public var chipTotal: Int {
        seats.reduce(0) { $0 + $1.chips } + (hand?.isComplete == false ? hand!.pot : 0)
    }

    public func seat(_ id: String) -> Seat? { seats.first { $0.id == id } }
    public func stake(_ id: String) -> Hand.Stake? { hand?.stakes.first { $0.id == id } }
    public func canJoin(_ id: String) -> Bool {
        guard !isFinished else { return false }
        guard let seat = seat(id) else { return seats.count < rules.capacity }
        return seat.hasLeft || (hand?.isComplete == true && seat.chips == 0)
    }

    public var summary: String {
        guard let hand else { return "\(seats.count)/\(rules.capacity) seated" }
        if hand.isComplete {
            let winners = awards.filter { $0.won > 0 }
            if winners.count == 1, let winner = winners.first, let seat = seat(winner.id) {
                return "\(seat.profile.name) won \(Chips.text(winner.won))"
            }
            return winners.allSatisfy({ $0.hand == winners.first?.hand }) ? "Split pot" : "Pots awarded"
        }
        return hand.turn.flatMap(seat).map { "\($0.profile.name)'s turn" } ?? "Hand \(hand.number)"
    }

    static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 256
            && id == id.trimmingCharacters(in: .whitespacesAndNewlines)
            && !id.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}

public enum Chips {
    public static func text(_ amount: Int) -> String {
        amount.formatted(.number.locale(Locale(identifier: "en_US")))
    }
}

public enum Bet: Codable, Equatable, Sendable {
    case fold, check, call, raiseTo(Int)
    public var name: String {
        switch self {
        case .fold: "Fold"
        case .check: "Check"
        case .call: "Call"
        case .raiseTo: "Raise"
        }
    }
}

public enum Action: Codable, Equatable, Sendable {
    case join(Profile), leave, deal(seed: UInt64), bet(Bet), timeout
}

public enum TableError: Error, LocalizedError, Equatable {
    case invalidState, invalidPlayer, tableFull, notYourTurn, illegalBet, expired, cannotDeal, finished, stale
    public var errorDescription: String? {
        switch self {
        case .invalidState: "This table could not be read."
        case .invalidPlayer: "Your seat is no longer available."
        case .tableFull: "This table is full."
        case .notYourTurn: "It is another player's turn."
        case .illegalBet: "That bet is no longer available."
        case .expired: "Your turn has expired. Resolve the turn to continue."
        case .cannotDeal: "Two players with chips are needed to deal."
        case .finished: "This table has finished."
        case .stale: "A newer table is available in the conversation."
        }
    }
}
