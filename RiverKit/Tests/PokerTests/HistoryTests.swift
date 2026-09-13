import Foundation
import Testing
@testable import Poker

@MainActor struct HistoryTests {
    @Test func twoDevicesKeepTheirOwnSenderBindings() throws {
        let suite = "river-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = TableHistory(defaults: defaults)
        let initial = try TableMessage(recording: .join(Profile(name: "Morgan", avatar: "M")!), on: Table(id: "test"), actor: "morgan")
        _ = try history.accept(initial, sender: "device-local-alias-M", localID: "sam")
        let joined = try TableMessage(recording: .join(Profile(name: "Sam", avatar: "S")!), on: initial.table, actor: "sam")
        _ = try history.accept(joined, sender: "sam", localID: "sam")
        let saved = try #require(defaults.data(forKey: "river.tables.v2"))
        var records = try #require(JSONSerialization.jsonObject(with: saved) as? [[String: Any]])
        records.append(["id": "corrupt", "url": try initial.url().absoluteString, "bindings": 0])
        defaults.set(try JSONSerialization.data(withJSONObject: records), forKey: "river.tables.v2")
        let reopened = TableHistory(defaults: defaults)
        #expect(reopened.latest("test")?.table == joined.table)
        #expect(try reopened.accept(initial, sender: "device-local-alias-M", localID: "sam").table == joined.table)
        #expect(try reopened.accept(joined, sender: "realiased-own-bubble", localID: "sam").table == joined.table)

        let departed = try TableMessage(recording: .leave, on: joined.table, actor: "morgan")
        #expect(throws: TableError.invalidPlayer) { try reopened.accept(departed, sender: "different-device-alias", localID: "sam") }
        let impersonating = try TableMessage(recording: .leave, on: joined.table, actor: "sam")
        #expect(throws: TableError.invalidPlayer) { try reopened.accept(impersonating, sender: "device-local-alias-M", localID: "sam") }
        _ = try reopened.accept(departed, sender: "device-local-alias-M", localID: "sam")
        #expect(reopened.latest("test")?.table.seats.count == 1)
        var table = departed.table
        for index in 0..<7 {
            let id = "replacement-\(index)"
            let join = try TableMessage(recording: .join(Profile(name: id, avatar: "R")!), on: table, actor: id)
            _ = try reopened.accept(join, sender: "alias-\(index)", localID: "sam")
            let leave = try TableMessage(recording: .leave, on: join.table, actor: id)
            table = try reopened.accept(leave, sender: "alias-\(index)", localID: "sam").table
        }
        #expect(table.seats.count == 1)
    }

    @Test func concurrentUpdatesChooseOneStableBranch() throws {
        let suite = "river-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = TableHistory(defaults: defaults)
        let initial = try TableMessage(recording: .join(Profile(name: "One", avatar: "1")!), on: Table(id: "test"), actor: "one")
        _ = try history.accept(initial, sender: "one", localID: "one")
        let left = try TableMessage(recording: .join(Profile(name: "Two", avatar: "2")!), on: initial.table, actor: "two")
        let right = try TableMessage(recording: .join(Profile(name: "Three", avatar: "3")!), on: initial.table, actor: "three")
        let winner = left.isNewer(than: right) ? left : right
        let loser = left.isNewer(than: right) ? right : left
        _ = try history.accept(winner, sender: "winner-alias", localID: "one")
        #expect(try history.accept(loser, sender: "loser-alias", localID: "one").fingerprint == winner.fingerprint)
        #expect(history.latest("test")?.fingerprint == winner.fingerprint)
    }
}
