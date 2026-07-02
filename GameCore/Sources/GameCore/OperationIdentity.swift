import Foundation

enum OperationIdentity {
    static let maxHistory = 64

    static func normalized(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func history(_ ids: [String]) -> [String] {
        Array(ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .orderedUnique()
            .suffix(maxHistory))
    }
}
