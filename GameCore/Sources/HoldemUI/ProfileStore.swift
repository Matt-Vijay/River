import Foundation
import GameCore
import Observation

/// The local player's chosen handle and emoji avatar. Persisted on-device
/// because Messages hides real contact names and photos.
@MainActor
@Observable
public final class ProfileStore {
    public var name: String
    public var avatar: String

    private let defaults: UserDefaults
    private let nameKey = "holdem.profile.name"
    private let avatarKey = "holdem.profile.avatar"

    public init(defaults: UserDefaults = .standard, resetProfile: Bool = false) {
        self.defaults = defaults
        if resetProfile {
            defaults.removeObject(forKey: nameKey)
            defaults.removeObject(forKey: avatarKey)
        }
        self.name = Self.normalizedStoredName(defaults.string(forKey: nameKey))
        self.avatar = ProfileText.avatar(defaults.string(forKey: avatarKey) ?? "")
    }

    public var hasProfile: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func save(name: String, avatar: String) {
        self.name = Self.normalizedStoredName(name)
        self.avatar = ProfileText.avatar(avatar)
        defaults.set(self.name, forKey: nameKey)
        defaults.set(self.avatar, forKey: avatarKey)
    }

    private static func normalizedStoredName(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return String(trimmed.prefix(ProfileText.maxNameLength))
    }
}
