import Foundation

public struct PlayerProfile: Sendable, Equatable {
    public let name: String
    public let avatar: String

    public init?(name: String, avatar: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        self.name = ProfileText.name(name)
        self.avatar = ProfileText.avatar(avatar)
    }
}

public enum ProfileText {
    static let maxNameLength = 24
    static let maxAvatarLength = 8

    public static func boundedEditingName(_ value: String) -> String {
        let withoutLeadingWhitespace = value.drop(while: \.isWhitespace)
        return String(withoutLeadingWhitespace.prefix(maxNameLength))
    }

    static func name(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String(trimmed.prefix(maxNameLength))
        return capped.isEmpty ? "Player" : capped
    }

    static func avatar(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String(trimmed.prefix(maxAvatarLength))
        return capped.isEmpty ? "🙂" : capped
    }

    static func decodedName(_ value: String, codingPath: [CodingKey]) throws -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Player name cannot be blank"
            ))
        }
        return name(value)
    }

    static func decodedAvatar(_ value: String, codingPath: [CodingKey]) throws -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Player avatar cannot be blank"
            ))
        }
        return avatar(value)
    }
}

public enum ChipText {
    public static func string(_ amount: Int) -> String {
        let value = max(0, amount)
        guard value >= 1_000 else { return "\(value)" }

        let digits = Array(String(value).reversed())
        var groups: [String] = []
        for start in stride(from: 0, to: digits.count, by: 3) {
            let end = min(start + 3, digits.count)
            groups.append(String(digits[start..<end].reversed()))
        }
        return groups.reversed().joined(separator: ",")
    }
}
