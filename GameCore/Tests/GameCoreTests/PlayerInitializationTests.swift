import Testing
import Foundation
@testable import GameCore

@Suite("Player initialization")
struct PlayerInitializationTests {
    @Test("negative starting stacks are normalized")
    func negativeStartingStacksAreNormalized() {
        let player = Player(id: "a", name: "Alice", avatar: "A", stack: -100)

        #expect(player.stack == 0)
    }

    @Test("empty player identities are replaced")
    func emptyPlayerIdentitiesAreReplaced() {
        let player = Player(id: "", name: "Alice", avatar: "A", stack: 100)

        #expect(!player.id.isEmpty)
    }

    @Test("player identities are trimmed and blank identities are replaced")
    func playerIdentitiesAreTrimmedAndBlankIdentitiesAreReplaced() {
        let padded = Player(id: "  a  ", name: "Alice", avatar: "A", stack: 100)
        let blank = Player(id: "   ", name: "Bob", avatar: "B", stack: 100)

        #expect(padded.id == "a")
        #expect(!blank.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("profile text is normalized")
    func profileTextIsNormalized() {
        let oversizedAvatar = String(repeating: "A", count: ProfileText.maxAvatarLength + 4)
        let player = Player(id: "a", name: "  Alice  ", avatar: "  \(oversizedAvatar)  ", stack: 100)
        let blank = Player(id: "b", name: "   ", avatar: "   ", stack: 100)

        #expect(player.name == "Alice")
        #expect(player.avatar == String(repeating: "A", count: ProfileText.maxAvatarLength))
        #expect(blank.name == "Player")
        #expect(blank.avatar == "🙂")
    }

    @Test("decoded players keep only two hole cards")
    func decodedPlayersKeepOnlyTwoHoleCards() throws {
        var player = Player(id: "a", name: "Alice", avatar: "A", stack: 100)
        player.holeCards = cards("Ah Kh Qh")

        let encoded = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: encoded)

        #expect(decoded.holeCards == cards("Ah Kh"))
    }
}
