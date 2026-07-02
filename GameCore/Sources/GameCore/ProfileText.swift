import Foundation

public enum ProfileText {
    public static let maxNameLength = 24
    public static let maxAvatarLength = 8

    public static func name(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String(trimmed.prefix(maxNameLength))
        return capped.isEmpty ? "Player" : capped
    }

    public static func avatar(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String(trimmed.prefix(maxAvatarLength))
        return capped.isEmpty ? "🙂" : capped
    }
}
