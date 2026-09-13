import Foundation
import Observation
import Poker

@MainActor @Observable
public final class RiverSession {
    public enum Surface {
        case invitation, table(Table), unavailable(String)
    }

    public enum Event {
        case profileSaved, action(Action), newTable, close, expand
    }

    public let isLocal: Bool
    public var localID: String
    public var surface = Surface.invitation
    public var isSending = false
    public var isVisible = true
    public var isCompact = false
    public var error: String?
    public private(set) var profile: Profile?
    public var onEvent: ((Event) -> Void)?
    private let defaults: UserDefaults

    public init(isLocal: Bool, resetProfile: Bool = false,
                defaults: UserDefaults = UserDefaults(suiteName: "group.com.dewylabs.river") ?? .standard) {
        self.isLocal = isLocal
        localID = isLocal ? "local" : ""
        self.defaults = defaults
        if resetProfile { defaults.removeObject(forKey: "holdem.profile") }
        refreshProfile()
    }

    public var table: Table? {
        guard case .table(let table) = surface else { return nil }
        return table
    }

    public var viewerID: String {
        isLocal ? table?.hand?.turn ?? table?.eligibleSeats.first?.id ?? localID : localID
    }

    public func save(_ profile: Profile) {
        guard self.profile == nil else { return }
        if storedProfile == nil {
            defaults.set(["name": profile.name, "avatar": profile.avatar], forKey: "holdem.profile")
        }
        refreshProfile()
        if !isLocal { onEvent?(.profileSaved) }
    }

    public func refreshProfile() {
        guard profile == nil, let saved = storedProfile else { return }
        profile = saved
        if isLocal, table == nil { newLocalTable() }
    }

    private var storedProfile: Profile? {
        guard let record = defaults.dictionary(forKey: "holdem.profile"),
              let name = record["name"] as? String, let avatar = record["avatar"] as? String else { return nil }
        return Profile(name: name, avatar: avatar)
    }

    func perform(_ event: Event) {
        guard !isSending else { return }
        guard isLocal else { onEvent?(event); return }
        switch event {
        case .action(let action):
            guard let table else { return }
            do {
                let next = try table.applying(action, by: viewerID)
                if next.hand == nil && next.seats.isEmpty { newLocalTable() }
                else { surface = .table(next) }
            } catch TableError.expired {
                // A tap at the deadline keeps the table and exposes timeout recovery.
            } catch { self.error = error.localizedDescription }
        case .newTable, .close: newLocalTable()
        default: break
        }
    }

    func act(_ action: Action, on snapshot: Poker.Table) {
        // Old controls can still deliver a tap before SwiftUI replaces them.
        guard table == snapshot else { return }
        perform(.action(action))
    }

    func addGuest() {
        guard isLocal, let table, table.hand == nil, !table.isFull else { return }
        let number = table.seats.count
        guard let profile = Profile(name: "Guest \(number)", avatar: Characters.all[number % Characters.all.count]) else { return }
        do { surface = .table(try table.applying(.join(profile), by: "guest-\(number)")) }
        catch { self.error = error.localizedDescription }
    }

    private func newLocalTable() {
        guard let profile else { return }
        do { surface = .table(try Table().applying(.join(profile), by: localID)) }
        catch { surface = .unavailable(error.localizedDescription) }
    }
}

public enum Characters {
    public static let all = ["\u{1F642}", "\u{1F9D1}\u{1F3FB}", "\u{1F9D1}\u{1F3FC}",
        "\u{1F9D1}\u{1F3FD}", "\u{1F9D1}\u{1F3FE}", "\u{1F9D1}\u{1F3FF}",
        "\u{1F469}\u{1F3FB}", "\u{1F468}\u{1F3FF}", "\u{1F431}", "\u{1F436}",
        "\u{1F98A}", "\u{1F43C}", "\u{1F47D}"]
}
