public enum StartingStack {
    public static let defaultAmount = 1000

    public static func normalized(_ stack: Int) -> Int {
        stack > 0 ? stack : defaultAmount
    }
}
