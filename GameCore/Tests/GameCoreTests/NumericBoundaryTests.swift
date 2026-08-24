import CryptoKit
import Foundation
import Testing
@testable import GameCore
@Suite("Numeric boundary verification")
struct NumericBoundaryTests {
    @Test("construction normalizes numeric extremes without trapping")
    func constructionNormalization() {
        let lo = Lobby(version: Int.min, smallBlind: Int.min, bigBlind: Int.min,
                       startingStack: Int.min)
        let hi = Lobby(version: Int.max, smallBlind: Int.max, bigBlind: Int.max,
                       startingStack: Int.max)
        let loGame = boundaryHand(Int.min, Int.min, Int.min, Int.min, Int.min)
        let hiGame = boundaryHand(Int.max, Int.max, Int.max, Int.max, Int.max)
        let rows: [(String, Int, Int)] = [
            ("stack.min", Player(id: "l", name: "L", avatar: "L", stack: Int.min).stack, 0),
            ("stack.max", Player(id: "h", name: "H", avatar: "H", stack: Int.max).stack,
             TableRules.tableMaximum),
            ("table.min", TableRules.table(Int.min), 0),
            ("table.max", TableRules.table(Int.max), TableRules.tableMaximum),
            ("version.min", lo.version, 0), ("version.max", hi.version, Int.max),
            ("smallBlind.min", lo.smallBlind, 1),
            ("smallBlind.max", hi.smallBlind, TableRules.buyInMaximum / 2),
            ("bigBlind.min", lo.bigBlind, 2),
            ("bigBlind.max", hi.bigBlind, TableRules.buyInMaximum),
            ("startingStack.min", lo.startingStack, Lobby.defaultStartingStack),
            ("startingStack.max", hi.startingStack, TableRules.buyInMaximum),
            ("hand.min", loGame.handNumber, 1), ("hand.max", hiGame.handNumber, Int.max),
            ("dealer.min", loGame.dealerIndex, 0), ("dealer.max", hiGame.dealerIndex, 1),
            ("gameBlind.min", loGame.smallBlind, 1),
            ("gameBlind.max", hiGame.bigBlind, TableRules.buyInMaximum),
            ("duration.min", Int(loGame.turnDuration), Int(TurnClock.defaultDuration)),
            ("duration.max", Int(hiGame.turnDuration), Int(TurnClock.maximumDuration)),
            ("saturatedAdd", TableRules.adding(Int.max, Int.max,
                                                limit: TableRules.tableMaximum),
             TableRules.tableMaximum),
        ]
        for (label, actual, expected) in rows {
            #expect(actual == expected, Comment(rawValue: label))
        }
        #expect(rows.count == 21)
    }
    @Test("v0/v1 migration and canonical v2 numeric policy")
    func versionScopedWirePolicy() throws {
        let rows = boundaryRows()
        var count = 0
        for row in rows {
            for version in [0, 1, 2] {
                let accepted = version < 2 ? row.legacyAccepted : row.v2Accepted
                let outcome = try outcome(row, version: version)
                #expect(matches(outcome, accepted: accepted),
                        Comment(rawValue: "v\(version) \(row.label)"))
                count += 1
            }
        }
        #expect(rows.count == 35)
        #expect(count == 105)
    }
    @Test("aggregate, action, time, and successor extremes never overflow")
    func overflowAndExhaustion() throws {
        var committed = liveState()
        for index in committed.players.indices { committed.players[index].committed = Int.max }
        #expect(committed.displayPot == TableRules.tableMaximum)
        var awarded = tiedState()
        awarded.results = awarded.players.map {
            HandResult(playerID: $0.id, amountWon: Int.max, handName: nil, bestFive: nil)
        }
        #expect(awarded.displayPot == TableRules.tableMaximum)
        let live = liveState(), actor = try #require(live.currentToAct)
        #expect(!live.legalActions(for: actor).allows(.raise(to: Int.min)))
        #expect(!live.legalActions(for: actor).allows(.raise(to: Int.max)))
        let earliest = Date(timeIntervalSince1970: TimeInterval(Int.min))
        let latest = Date(timeIntervalSince1970: TimeInterval(Int.max))
        #expect(TurnClock.remainingSeconds(startedAt: earliest, duration: 30, at: latest) == 0)
        #expect(TurnClock.remainingSeconds(startedAt: latest, duration: 30, at: earliest) == 30)
        #expect(MonotonicCounter.successor(of: Int.min) == Int.min + 1)
        #expect(MonotonicCounter.successor(of: Int.max - 1) == Int.max)
        #expect(MonotonicCounter.successor(of: Int.max) == nil)
        let lobby = TableMessage.lobby(Lobby(
            tableID: "exhausted", version: Int.max,
            seats: [LobbySeat(id: "a", name: "A", avatar: "A")]))
        #expect(lobby.committing(.joinLobby(name: "B", avatar: "B"), actorID: "b")
                == .rejected(.illegalAction))
        var hand = tiedState(); hand.handNumber = Int.max
        #expect(hand.startNextHand(seed: 1) == nil)
    }
}
private typealias Mutation = (inout [String: Any]) throws -> Void
private struct BoundaryRow {
    let label: String, message: TableMessage
    let legacyAccepted, v2Accepted: Bool
    let mutation: Mutation
    init(_ label: String, _ message: TableMessage, legacy: Bool = true,
         v2: Bool = false, _ mutation: @escaping Mutation) {
        self.label = label; self.message = message; legacyAccepted = legacy
        v2Accepted = v2; self.mutation = mutation
    }
}
private func boundaryRows() -> [BoundaryRow] {
    let live = TableMessage.game(liveState()), lobby = TableMessage.lobby(Lobby())
    let tied = TableMessage.game(tiedState())
    var rows = [
        BoundaryRow("stack.min", live, player("stack", Int.min)),
        BoundaryRow("stack.max", live, player("stack", Int.max)),
        BoundaryRow("bet.min", live, player("bet", Int.min)),
        BoundaryRow("bet.max", live, player("bet", Int.max)),
        BoundaryRow("committed.min", live, player("committed", Int.min)),
        BoundaryRow("committed.max", live, { try player("committed", Int.max)(&$0)
            $0["pot"] = TableRules.tableMaximum }),
        BoundaryRow("smallBlind.min", live, field("smallBlind", Int.min)),
        BoundaryRow("smallBlind.max", live, field("smallBlind", Int.max)),
        BoundaryRow("bigBlind.min", live, field("bigBlind", Int.min)),
        BoundaryRow("bigBlind.max", live, field("bigBlind", Int.max)),
        BoundaryRow("startingStack.min", lobby, field("startingStack", Int.min)),
        BoundaryRow("startingStack.max", lobby, field("startingStack", Int.max)),
        BoundaryRow("game.version.min", live, field("version", Int.min)),
        BoundaryRow("lobby.version.min", lobby, field("version", Int.min)),
        BoundaryRow("hand.min", live, field("handNumber", Int.min)),
        BoundaryRow("minRaise.min", live, field("minRaise", Int.min)),
        BoundaryRow("minRaise.max", live, field("minRaise", Int.max)),
        BoundaryRow("duration.min", live, field("turnDuration", Int.min)),
        BoundaryRow("duration.max", live, field("turnDuration", Int.max)),
        BoundaryRow("timestamp.min", live, field("turnStartedAt", Int.min)),
        BoundaryRow("timestamp.max", live, field("turnStartedAt", Int.max)),
        BoundaryRow("raise.min", live, raiseTotal(Int.min)),
        BoundaryRow("raise.max", live, raiseTotal(Int.max)),
        BoundaryRow("award.min", tied, result(Int.min)),
        BoundaryRow("award.max", tied, result(Int.max)),
        BoundaryRow("award.sum.max", tied, allResults(Int.max)),
    ]
    rows += [
        BoundaryRow("pot.min", live, legacy: false, field("pot", Int.min)),
        BoundaryRow("pot.max", live, legacy: false, field("pot", Int.max)),
        BoundaryRow("dealer.min", live, legacy: false, field("dealerIndex", Int.min)),
        BoundaryRow("dealer.max", live, legacy: false, field("dealerIndex", Int.max)),
        BoundaryRow("actor.min", live, legacy: false, field("currentToAct", Int.min)),
        BoundaryRow("actor.max", live, legacy: false, field("currentToAct", Int.max)),
        BoundaryRow("game.version.max", live, v2: true, field("version", Int.max)),
        BoundaryRow("lobby.version.max", lobby, v2: true, field("version", Int.max)),
        BoundaryRow("hand.max", live, v2: true, field("handNumber", Int.max)),
    ]
    return rows
}
private func boundaryHand(_ dealer: Int, _ small: Int, _ big: Int,
                          _ hand: Int, _ duration: Int) -> GameState {
    GameState.startHand(players: makePlayers([1_000, 1_000]), dealerIndex: dealer,
        smallBlind: small, bigBlind: big, seed: 1, handNumber: hand,
        turnDuration: TimeInterval(duration), now: Date(timeIntervalSince1970: 1))
}

private func liveState() -> GameState {
    var state = boundaryHand(0, 10, 20, 1, 30)
    var observer = Player(id: "o", name: "O", avatar: "O", stack: 0)
    observer.status = .sittingOut; state.players.append(observer)
    return state
}

private func tiedState() -> GameState {
    var state = boundaryHand(0, 10, 20, 1, 30)
    state.players[0].holeCards = cards("2c 3d"); state.players[1].holeCards = cards("4c 5d")
    state.board = cards("Ah Kh Qh Jh Th")
    let visible = Set(state.players.flatMap(\.holeCards) + state.board)
    state.deck = Card.fullDeck.filter { !visible.contains($0) }
    for index in state.players.indices {
        state.players[index].stack = 1_000; state.players[index].bet = 0
        state.players[index].committed = 10; state.players[index].lastActionBet = nil
    }
    state.street = .showdown; state.currentToAct = nil; state.minRaise = 0
    state.turnStartedAt = nil
    let rank = HandEvaluator.evaluate(state.board)
    state.results = state.players.map { HandResult(
        playerID: $0.id, amountWon: 10, handName: rank.name, bestFive: rank.bestFive) }
    return state
}

private func field(_ key: String, _ value: Int) -> Mutation { { $0[key] = value } }
private func player(_ key: String, _ value: Int) -> Mutation { { game in
    var players = try #require(game["players"] as? [[String: Any]])
    players[2][key] = value; game["players"] = players
} }
private func raiseTotal(_ value: Int) -> Mutation { { game in
    var players = try #require(game["players"] as? [[String: Any]])
    players[2]["lastAction"] = try JSONSerialization.jsonObject(
        with: GamePayload.encoder.encode(PlayerAction.raise(to: value)))
    game["players"] = players
} }
private func result(_ value: Int) -> Mutation { { game in
    var results = try #require(game["results"] as? [[String: Any]])
    results[0]["amountWon"] = value; game["results"] = results
} }
private func allResults(_ value: Int) -> Mutation { { game in
    var results = try #require(game["results"] as? [[String: Any]])
    for index in results.indices { results[index]["amountWon"] = value }
    game["results"] = results
} }

private func outcome(_ row: BoundaryRow, version: Int) throws -> GamePayload.DecodeOutcome {
    var root = try #require(JSONSerialization.jsonObject(
        with: GamePayload.encoder.encode(row.message)) as? [String: Any])
    let key = if case .game = row.message { "game" } else { "lobby" }
    var wrapper = try #require(root[key] as? [String: Any])
    var state = try #require(wrapper["_0"] as? [String: Any]); try row.mutation(&state)
    wrapper["_0"] = state; root[key] = wrapper; root.removeValue(forKey: "integrity")
    if version == 0 { root.removeValue(forKey: "wireVersion") } else { root["wireVersion"] = version }
    if version == 2 {
        let stateData = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
        var framed = Data("river-table-state-v1\0".utf8); framed.append(contentsOf: key.utf8)
        framed.append(0); framed.append(stateData)
        root["integrity"] = SHA256.hash(data: framed).map { String(format: "%02x", $0) }.joined()
    }
    let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    return GamePayload.decodeOutcome(from: data.base64URLEncodedString())
}

private func matches(_ outcome: GamePayload.DecodeOutcome, accepted: Bool) -> Bool {
    if case .decoded = outcome { return accepted }
    return !accepted && outcome == .rejected(.invalidState)
}
