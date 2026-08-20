import Foundation

public enum TurnClock {
    public static let defaultDuration: TimeInterval = 30
    static let maximumDuration: TimeInterval = 5 * 60

    public static func normalized(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return defaultDuration }
        return min(duration, maximumDuration)
    }

    public static func remainingFraction(
        startedAt: Date,
        duration: TimeInterval,
        at date: Date
    ) -> Double {
        let duration = normalized(duration)
        let elapsed = date.timeIntervalSince(startedAt)
        return max(0, min(1, 1 - elapsed / duration))
    }

    public static func remainingSeconds(
        startedAt: Date,
        duration: TimeInterval,
        at date: Date
    ) -> Int {
        Int(ceil(normalized(duration) * remainingFraction(
            startedAt: startedAt,
            duration: duration,
            at: date
        )))
    }
}

public extension GameState {
    func isTurnExpired(at now: Date = Date()) -> Bool {
        guard let index = currentToAct,
              players.indices.contains(index),
              players[index].canAct,
              let startedAt = turnStartedAt else { return false }
        return now.timeIntervalSince(startedAt) >= turnDuration
    }
}

extension GameState {
    @discardableResult
    mutating func resolveTimeout(now: Date = Date()) -> Bool {
        guard isTurnExpired(at: now), let index = currentToAct else { return false }
        let legal = legalActions(for: index)
        return applyCurrent(legal.canCheck ? .check : .fold, by: index, now: now)
    }
}
