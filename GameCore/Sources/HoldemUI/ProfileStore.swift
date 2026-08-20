import Foundation
import GameCore

/// The local player's chosen handle and emoji avatar. Persisted on-device
/// because Messages hides real contact names and photos.
@MainActor
public struct ProfileStore {
    private let defaults: UserDefaults
    private static let profileKey = "holdem.profile"
    private static let playerIDKey = "holdem.player.id.v1"

    public init(resetProfile: Bool = false) {
        self.init(defaults: UserDefaults(suiteName: "group.com.dewylabs.river") ?? .standard,
                  resetProfile: resetProfile)
    }

    init(defaults: UserDefaults, resetProfile: Bool = false) {
        self.defaults = defaults
        if resetProfile {
            defaults.removeObject(forKey: Self.profileKey)
        }
    }

    public var configuredProfile: PlayerProfile? {
        guard let record = defaults.dictionary(forKey: Self.profileKey),
              let name = record["name"] as? String,
              let avatar = record["avatar"] as? String,
              let profile = PlayerProfile(name: name, avatar: avatar) else {
            defaults.removeObject(forKey: Self.profileKey)
            return nil
        }
        return profile
    }

    public func save(_ profile: PlayerProfile) {
        defaults.set(["name": profile.name, "avatar": profile.avatar],
                     forKey: Self.profileKey)
    }

    /// Stable across launches so existing table seats remain addressable.
    public func playerID(seed: String) -> String {
        if let stored = defaults.string(forKey: Self.playerIDKey),
           let id = UUID(uuidString: stored) {
            return id.uuidString
        }

        let id = UUID(uuidString: seed)?.uuidString ?? UUID().uuidString
        defaults.set(id, forKey: Self.playerIDKey)
        return id
    }
}
