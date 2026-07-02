public enum TableSize {
    public static let minPlayers = 2
    public static let maxPlayers = 6

    public static func normalizedMaxPlayers(_ value: Int) -> Int {
        min(max(value, minPlayers), maxPlayers)
    }
}
