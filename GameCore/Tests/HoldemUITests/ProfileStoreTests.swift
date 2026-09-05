import Foundation
import Testing
import GameCore
@testable import HoldemUI

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
        #expect(store.configuredProfile == nil)
        store.save(PlayerProfile(name: "  Maverick  ", avatar: "Ace")!)

        let preserved = ProfileStore(defaults: defaults)
        #expect(preserved.configuredProfile?.name == "Maverick")
        #expect(preserved.configuredProfile?.avatar == "Ace")

        let reset = ProfileStore(defaults: defaults, resetProfile: true)
        #expect(reset.configuredProfile == nil)
    }

    @MainActor
    @Test("profile store normalizes persisted profile text")
    func normalizesPersistedProfileText() {
        let suiteName = "holdem.profile.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set([
            "name": "  \(String(repeating: "M", count: 28))  ",
            "avatar": "   ",
        ], forKey: "holdem.profile")
        let normalized = ProfileStore(defaults: defaults)
        #expect(normalized.configuredProfile?.name == String(repeating: "M", count: 24))
        #expect(normalized.configuredProfile?.avatar == "🙂")

        defaults.set(["name": "   ", "avatar": "Ace"], forKey: "holdem.profile")
        let blank = ProfileStore(defaults: defaults)
        #expect(blank.configuredProfile == nil)
    }
}
