import Foundation
import Testing
@testable import Poker

struct LegacyTests {
    struct Fixture: Decodable { let name: String; let url: URL; let json: String }

    @Test func importsPreservedAppMessagesAndContinuesWithCurrentRules() throws {
        let path = try #require(Bundle.module.url(forResource: "legacy", withExtension: "json", subdirectory: "Fixtures"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: path))
        for fixture in fixtures {
            let message = try TableMessage(url: fixture.url)
            #expect(try message.url() == fixture.url)
            let original = try #require(JSONSerialization.jsonObject(with: Data(fixture.json.utf8)) as? [String: Any])
            let wrapped = try #require(original[message.table.hand == nil ? "lobby" : "game"] as? [String: Any])
            let state = try #require(wrapped["_0"] as? [String: Any])
            #expect(message.table.version == state["version"] as? Int, "\(fixture.name)")
            if let hand = message.table.hand {
                #expect(hand.board.map(\.id) == state["board"] as? [Int], "\(fixture.name)")
                let players = try #require(state["players"] as? [[String: Any]])
                for player in players {
                    let id = try #require(player["id"] as? String)
                    #expect(message.table.seat(id)?.chips == player["stack"] as? Int)
                    #expect(hand.cards(for: id).map(\.id) == player["holeCards"] as? [Int])
                }
            }
            let table = message.table
            let actor = table.hand?.turn ?? "p0"
            let action: Action = table.hand == nil ? .join(Profile(name: "New", avatar: "N")!)
                : table.canDeal ? .deal(seed: 8) : .bet(.fold)
            let next = try TableMessage(recording: action, on: table,
                actor: table.hand == nil ? "new" : actor, at: Date(timeIntervalSince1970: 1_783_333_333.125))
            #expect(next.verifies(after: table))
            #expect(try TableMessage(url: next.url()).table == next.table)
            #expect(next.isNewer(than: message))
        }
    }

    @MainActor @Test(arguments: [false, true])
    func importsSavedIdentityAndRejectsOlderLegacyBubbles(corruptNeighbor: Bool) throws {
        let path = try #require(Bundle.module.url(forResource: "legacy", withExtension: "json", subdirectory: "Fixtures"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: path))
        let latest = try TableMessage(url: fixtures[1].url)
        let suite = "river-legacy-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var records: [[String: Any]] = [["tableID": latest.table.id,
            "revision": ["tableID": latest.table.id, "phase": 0, "version": latest.table.version,
                         "branch": try #require(latest.legacyBranch)],
            "participants": ["seats": ["remote-morgan": "p0"]]]]
        if corruptNeighbor { records.append(["tableID": "corrupt", "participants": 0]) }
        defaults.set(try JSONSerialization.data(withJSONObject: records), forKey: "RiverTableHistory.v1")
        let history = TableHistory(defaults: defaults)
        #expect(throws: TableError.stale) {
            try history.accept(TableMessage(url: fixtures[0].url), sender: "remote-morgan", localID: "p1")
        }
        #expect(try history.accept(latest, sender: "realiased-own-bubble", localID: "p1").table == latest.table)
        let departed = try TableMessage(recording: .leave, on: latest.table, actor: "p0")
        #expect(throws: TableError.invalidPlayer) { try history.accept(departed, sender: "impostor", localID: "p1") }
        #expect(try history.accept(departed, sender: "remote-morgan", localID: "p1").table == departed.table)
    }
}
