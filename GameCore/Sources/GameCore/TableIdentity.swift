import Foundation

enum TableIdentity {
    static func normalized(_ tableID: String) -> String {
        let trimmed = tableID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }
}
