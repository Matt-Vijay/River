import Foundation

public enum TurnClock {
    public static let defaultDuration: TimeInterval = 30

    public static func normalized(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return defaultDuration }
        return duration
    }
}
