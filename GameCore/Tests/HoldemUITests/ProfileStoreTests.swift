import Foundation
import Testing
import GameCore
import HoldemUI

@Suite("Profile store")
struct ProfileStoreTests {
    @MainActor
    @Test("profile store preserves saved profile unless reset is explicit")
    func preservesSavedProfileUnlessResetIsExplicit() {
        let suiteName = "holdem.profile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProfileStore(defaults: defaults)
        store.save(name: "  Maverick  ", avatar: "Ace")

        let preserved = ProfileStore(defaults: defaults)
        #expect(preserved.hasProfile)
        #expect(preserved.name == "Maverick")
        #expect(preserved.avatar == "Ace")

        let reset = ProfileStore(defaults: defaults, resetProfile: true)
        #expect(!reset.hasProfile)
    }

    @MainActor
    @Test("profile store normalizes blank avatars")
    func normalizesBlankAvatars() {
        let suiteName = "holdem.profile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProfileStore(defaults: defaults)
        store.save(name: "Maverick", avatar: "   ")

        #expect(store.avatar == "🙂")
        #expect(defaults.string(forKey: "holdem.profile.avatar") == "🙂")

        defaults.set("   ", forKey: "holdem.profile.avatar")
        let restored = ProfileStore(defaults: defaults)

        #expect(restored.avatar == "🙂")
    }

    @MainActor
    @Test("profile store caps oversized avatars")
    func capsOversizedAvatars() {
        let suiteName = "holdem.profile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let oversized = String(repeating: "A", count: ProfileText.maxAvatarLength + 4)

        let store = ProfileStore(defaults: defaults)
        store.save(name: "Maverick", avatar: oversized)

        #expect(store.avatar == String(repeating: "A", count: ProfileText.maxAvatarLength))
        #expect(defaults.string(forKey: "holdem.profile.avatar") == store.avatar)
    }

    @MainActor
    @Test("profile store caps long names without completing blank profiles")
    func capsLongNamesWithoutCompletingBlankProfiles() {
        let suiteName = "holdem.profile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProfileStore(defaults: defaults)
        store.save(name: String(repeating: "M", count: ProfileText.maxNameLength + 4),
                   avatar: "Ace")

        #expect(store.name == String(repeating: "M", count: ProfileText.maxNameLength))
        #expect(store.hasProfile)

        defaults.set("   ", forKey: "holdem.profile.name")
        let blank = ProfileStore(defaults: defaults)

        #expect(blank.name == "")
        #expect(!blank.hasProfile)
    }
}
