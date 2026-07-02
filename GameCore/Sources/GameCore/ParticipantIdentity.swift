import Foundation

enum ParticipantIdentity {
    static func normalized(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }

    static func uniquePlayers(_ players: [Player]) -> [Player] {
        var seen: Set<String> = []
        return players.map { player in
            var copy = player
            copy.id = uniqueID(copy.id, seen: &seen)
            return copy
        }
    }

    private static func uniqueID(_ id: String, seen: inout Set<String>) -> String {
        var candidate = normalized(id)
        while !seen.insert(candidate).inserted {
            candidate = UUID().uuidString
        }
        return candidate
    }
}
