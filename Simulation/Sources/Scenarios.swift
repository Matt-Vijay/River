import Foundation
import Poker

extension LocalSimulation {
    func exercise() throws -> Report {
        try create(by: 0)
        let invitation = packets[0]
        try deliverAll()
        try require(players.dropFirst().allSatisfy { $0.session.table == nil }, "Receiving an invitation joined a player")
        checks.append("Receiving an invitation does not join")

        try open(1)
        try open(2)
        try deliverAll(reversed: true)
        let loser = players[1...2].first { $0.session.table?.canJoin($0.id) == true }!
        try require(Set(players[0...2].compactMap { $0.latest?.fingerprint }).count == 1, "Concurrent joins diverged")
        try open(loser.index)
        try deliverAll()
        try open(3)
        try deliverAll()
        try require(players[0].session.table?.seats.count == 4, "A concurrent join was not recoverable")
        checks.append("Concurrent joins converge; reopening recovers the losing seat")

        try playTurn()
        try deliverAll()
        let hand = players[0].session.table!.hand
        try open(4)
        try deliverAll()
        try require(players[4].session.table?.hand == hand, "Late join modified the current hand")
        try require(players[4].session.table?.hand?.cards(for: players[4].id).isEmpty == true, "Late join received cards")
        try send(.leave, from: 4)
        try deliverAll()
        try open(4)
        try deliverAll()
        try verifyAgreement()
        checks.append("Late join, leave and rejoin preserve the hand and chips")

        players[4].online = false
        let offlineTable = players[4].session.table!
        try playTurn()
        try deliverAll()
        try require(players[4].session.table == offlineTable && !queue.isEmpty, "Offline client received an update")
        do { try send(.leave, from: 4); throw Failure(message: "Offline send succeeded") }
        catch is URLError { }
        checks.append("Disconnected client retains its own snapshot; offline send fails")

        let before = players[1].latest!.fingerprint
        try receive(packets.last!, at: 1)
        try receive(invitation, at: 1)
        try require(players[1].latest?.fingerprint == before, "Duplicate or stale message rolled state back")
        do {
            try receive(Packet(sender: 0, url: "data:,river?g=not-a-message"), at: 1)
            throw Failure(message: "Malformed message was accepted")
        } catch is Failure { throw Failure(message: "Malformed message was accepted") }
        catch { try require(players[1].latest?.fingerprint == before, "Malformed message replaced the table") }
        checks.append("Duplicate, stale and malformed deliveries preserve accepted state")

        let acting = players.first { $0.id == players[0].session.table?.hand?.turn }!
        let observer = players.first { $0.index != acting.index && $0.index != 4 }!
        let next = try TableMessage(recording: .bet(.fold), on: acting.session.table!, actor: acting.id, at: now)
        do {
            try receive(Packet(sender: acting.index, url: next.url().absoluteString), at: observer.index,
                        senderOverride: observer.id)
            throw Failure(message: "A remote action impersonated the local sender")
        } catch TableError.invalidPlayer { }
        checks.append("Sender impersonation is rejected")

        for _ in 0..<3 { try playTurn(); try deliverAll() }
        for _ in 0..<50 where players[0].session.table?.hand?.turn != players[4].id {
            try playTurn()
            try deliverAll()
        }
        try require(players[0].session.table?.hand?.turn == players[4].id, "Offline player never reached its turn")
        let waiting = players[0].latest!.fingerprint
        try playTurn()
        try require(players[0].latest?.fingerprint == waiting, "Offline turn advanced before its deadline")
        clock = Date(timeIntervalSince1970: Double(players[0].session.table!.hand!.deadline!) / 1_000 + 0.001)
        try playTurn()
        try deliverAll()
        checks.append("Offline player's timeout uses an online client's current deadline")
        players[4].online = true
        try deliverAll(reversed: true)
        try restart(3)
        try deliverAll()
        try verifyAgreement()
        checks.append("Reordered reconnect and process restart recover the same state")

        if let deadline = players[0].session.table?.hand?.deadline {
            clock = Date(timeIntervalSince1970: Double(deadline) / 1_000 + 0.001)
            try playTurn()
            try deliverAll()
            try verifyAgreement()
            checks.append("Expired turn resolves consistently on five clients")
        }

        var steps = 0
        while let table = players[0].session.table, !table.isFinished {
            if table.hand?.number == 9, table.hand?.isComplete == true { break }
            steps += 1
            try require(steps <= 500, "Simulation stopped making progress")
            try playTurn(allIn: (table.hand?.number ?? 0) >= 9)
            try deliverAll(reversed: steps % 3 == 0)
            if steps % 11 == 0 { try receive(packets.last!, at: (steps / 11) % 5) }
            try verifyAgreement()
        }
        let tables = players.compactMap { $0.session.table }
        try require(tables[0].hand?.isComplete == true, "Final hand did not settle")
        checks.append("Repeated five-player hands, raises, folds and all-ins conserve 5,000 chips")
        record("PASS: \(checks.count) scenario checks")
        return Report(seed: seed, checks: checks, hands: tables[0].hand!.number,
                      packets: packets, events: events, finalTables: tables)
    }
}
