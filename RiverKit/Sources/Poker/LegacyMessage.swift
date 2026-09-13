import Foundation

/// One-way import of the previous checksummed wire format. No legacy rules engine
/// remains: the next local action produces a current-format message.
struct LegacyMessage {
    let table: Table
    let move: TableMessage.Move
    let branch: String

    private struct Wrapped<Value: Codable>: Codable { let _0: Value }
    private struct Envelope: Codable {
        let wireVersion: Int
        let integrity: String
        let lobby: Wrapped<Lobby>?
        let game: Wrapped<Game>?
    }
    private struct Lobby: Codable {
        struct Player: Codable { let id: String; let name: String; let avatar: String }
        let tableID: String
        let version: Int
        let seats: [Player]
        let maxPlayers: Int
        let smallBlind: Int
        let bigBlind: Int
        let startingStack: Int
    }
    private struct Game: Codable {
        struct Player: Codable {
            let id: String
            let name: String
            let avatar: String
            let stack: Int
            let bet: Int
            let committed: Int
            let status: String
            let holeCards: [Card]
            let lastActionBet: Int?
            let hasActed: Bool
            let lastAction: LegacyBet?
            let hasLeft: Bool
        }
        struct Result: Codable {
            let playerID: String
            let amountWon: Int
            let handName: String?
            let bestFive: [Card]?
        }
        let tableID: String
        let version: Int
        let players: [Player]
        let handNumber: Int
        let dealerIndex: Int
        let smallBlind: Int
        let bigBlind: Int
        let board: [Card]
        let deck: [Card]
        let street: Int
        let pot: Int
        let currentToAct: Int?
        let minRaise: Int
        let turnStartedAt: Double?
        let turnDuration: Double
        let results: [Result]?
    }
    private enum LegacyBet: Codable {
        case fold, check, call, raise(to: Int)
        var current: Bet {
            switch self {
            case .fold: .fold
            case .check: .check
            case .call: .call
            case .raise(let total): .raiseTo(total)
            }
        }
    }
    private enum Operation: Codable {
        case joinLobby(name: String, avatar: String)
        case startGame(seed: UInt64, turnDuration: Double)
        case leaveLobby, gameAction(LegacyBet), resolveTimeout
        case joinGame(name: String, avatar: String, startingStack: Int)
        case leaveGame, dealNextHand(seed: UInt64)

        func current() throws -> Action {
            switch self {
            case .joinLobby(let name, let avatar), .joinGame(let name, let avatar, _):
                // Older clients stripped joiners along with all other controls.
                let name = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
                guard let profile = Profile(name: name, avatar: avatar) else { throw TableError.invalidState }
                return .join(profile)
            case .startGame(let seed, _), .dealNextHand(let seed): return .deal(seed: seed)
            case .leaveLobby, .leaveGame: return .leave
            case .gameAction(let bet): return .bet(bet.current)
            case .resolveTimeout: return .timeout
            }
        }
    }
    private struct Receipt: Codable {
        struct Reference: Codable {
            struct Revision: Codable {
                let tableID: String
                let phase: Int
                let version: Int
                let branch: String
            }
            let r: Revision
            let f: String
        }
        struct Body: Codable {
            let v: Int
            let a: String
            let p: Reference
            let o: Operation
            let t: UInt64
            let r: Reference
        }
        let b: Body
        let h: String
    }

    init(url: URL) throws {
        guard url.absoluteString.utf8.count <= 5_000,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "data", components.path == ",river", components.host == nil,
              components.fragment == nil, components.user == nil, components.password == nil,
              components.port == nil, let items = components.queryItems, items.count == 2,
              Set(items.map(\.name)) == ["g", "r"],
              let payload = items.first(where: { $0.name == "g" })?.value,
              let proof = items.first(where: { $0.name == "r" })?.value else { throw TableError.invalidState }
        let bytes = try TableMessage.decodeBase64(payload.first == "z" ? String(payload.dropFirst()) : payload)
        let data = try payload.first == "z" ? TableMessage.decompress(bytes) : bytes
        guard data.count <= 16_384 else { throw TableError.invalidState }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.wireVersion == 2, try Self.encode(envelope) == data,
              (envelope.lobby != nil) != (envelope.game != nil) else { throw TableError.invalidState }
        let kind = envelope.lobby == nil ? "game" : "lobby"
        let state = try envelope.lobby.map { try Self.encode($0._0) } ?? Self.encode(envelope.game!._0)
        let canonical = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: state), options: [.sortedKeys])
        var framed = Data("river-table-state-v1\u{0}\(kind)\u{0}".utf8)
        framed.append(canonical)
        let integrity = TableMessage.hash(framed)
        guard integrity == envelope.integrity else { throw TableError.invalidState }

        let receiptData = try TableMessage.decodeBase64(proof)
        guard receiptData.count <= 1_024 else { throw TableError.invalidState }
        let receipt = try JSONDecoder().decode(Receipt.self, from: receiptData)
        var signed = Data("river-table-mutation-v1\u{0}".utf8)
        signed.append(try Self.encode(receipt.b))
        let parent = receipt.b.p.r
        let result = receipt.b.r.r
        let appliedAt = Date(timeIntervalSinceReferenceDate: Double(bitPattern: receipt.b.t)).timeIntervalSince1970
        guard try Self.encode(receipt) == receiptData, receipt.h == TableMessage.hash(signed),
              receipt.b.v == 1, Table.validID(receipt.b.a), appliedAt.isFinite,
              (0...253_402_300_000).contains(appliedAt),
              parent.tableID == result.tableID, (0...1).contains(parent.phase), (0...1).contains(result.phase),
              parent.version >= 0, result.version >= 0,
              (parent.phase, parent.version) < (result.phase, result.version),
              receipt.b.p.f == parent.branch, receipt.b.r.f == result.branch,
              parent.branch.utf8.count == 32,
              parent.branch.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              result.branch == String(integrity.prefix(32)) else { throw TableError.invalidState }
        let converted = try envelope.lobby.map(Self.convert) ?? Self.convert(envelope.game!._0)
        guard result.tableID == converted.id, result.version == converted.version,
              result.phase == (converted.hand == nil ? 0 : 1) else { throw TableError.invalidState }
        table = try converted.validated()
        branch = result.branch
        move = TableMessage.Move(actor: receipt.b.a, action: try receipt.b.o.current(),
                                 parent: parent.branch, time: Int64((appliedAt * 1_000).rounded(.down)))
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func profile(_ name: String, _ avatar: String) throws -> Profile {
        guard !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let profile = Profile(name: name, avatar: avatar), profile.name == name, profile.avatar == avatar else {
            throw TableError.invalidState
        }
        return profile
    }

    private static func convert(_ wrapped: Wrapped<Lobby>) throws -> Table {
        let lobby = wrapped._0
        var rules = Rules.standard
        rules.capacity = lobby.maxPlayers
        rules.smallBlind = lobby.smallBlind
        rules.bigBlind = lobby.bigBlind
        rules.buyIn = lobby.startingStack
        var table = Table(id: lobby.tableID, rules: rules)
        table.version = lobby.version
        table.seats = try lobby.seats.map { Seat(id: $0.id, profile: try profile($0.name, $0.avatar), chips: rules.buyIn) }
        return table
    }

    private static func convert(_ game: Game) throws -> Table {
        guard (2...6).contains(game.players.count), game.players.indices.contains(game.dealerIndex),
              (1...300).contains(game.turnDuration), game.turnDuration.rounded() == game.turnDuration,
              [0, 3, 4, 5].contains(game.board.count) else { throw TableError.invalidState }
        var rules = Rules.standard
        rules.smallBlind = game.smallBlind
        rules.bigBlind = game.bigBlind
        rules.turnSeconds = Int(game.turnDuration)
        var table = Table(id: game.tableID, rules: rules)
        table.version = game.version
        table.seats = try game.players.map { Seat(id: $0.id, profile: try profile($0.name, $0.avatar), chips: $0.stack, hasLeft: $0.hasLeft) }
        let dealt = (1...game.players.count).map { game.players[(game.dealerIndex + $0) % game.players.count] }
            .filter { !$0.holeCards.isEmpty }
        guard dealt.allSatisfy({ $0.holeCards.count == 2 }),
              game.players.allSatisfy({ ["active", "folded", "allIn", "sittingOut", "eliminated"].contains($0.status)
                  && (0...Rules.chipLimit).contains($0.stack) && (0...Rules.chipLimit).contains($0.bet)
                  && (0...Rules.chipLimit).contains($0.committed)
                  && $0.hasActed == ($0.lastActionBet != nil) }) else { throw TableError.invalidState }
        let cards = dealt.map { $0.holeCards[0] } + dealt.map { $0.holeCards[1] } + game.board + game.deck
        let complete = game.results != nil
        let street = Hand.Street.allCases.first { $0.cardCount == game.board.count }!
        guard game.street == (complete ? 4 : street.rawValue),
              game.pot == (complete ? 0 : game.players.reduce(0) { $0 + $1.committed - $1.bet }),
              game.currentToAct.map(game.players.indices.contains) ?? complete else { throw TableError.invalidState }
        var hand = Hand(number: game.handNumber, dealerID: game.players[game.dealerIndex].id, deck: cards,
                        stakes: dealt.map { Hand.Stake(id: $0.id, bet: $0.bet, committed: $0.committed,
                            folded: $0.status == "folded" || $0.status == "sittingOut", actedAtBet: $0.lastActionBet,
                            lastAction: $0.lastAction?.current) }, raiseIncrement: game.minRaise)
        hand.street = street
        hand.isComplete = complete
        hand.turn = game.currentToAct.map { game.players[$0].id }
        if let start = game.turnStartedAt {
            guard start.isFinite, (0...253_402_300_000_000).contains(start) else { throw TableError.invalidState }
            hand.deadline = Int64(start.rounded(.down)) + Int64(rules.turnSeconds * 1_000)
        }
        table.hand = hand
        _ = try table.validated()
        if let results = game.results {
            let awards = table.awards.filter { $0.won > 0 }
            guard results.count == awards.count, Set(results.map(\.playerID)).count == results.count,
                  results.allSatisfy({ result in awards.contains { $0.id == result.playerID && $0.won == result.amountWon } }) else {
                throw TableError.invalidState
            }
        }
        return table
    }
}
