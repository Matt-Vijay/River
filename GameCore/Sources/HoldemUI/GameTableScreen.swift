import SwiftUI
import GameCore

/// A self-contained demo of the real flow on one device: set up the local
/// profile, join the lobby, ready up, and play. Real remote multiplayer —
/// each person on their own phone — is the iMessage extension.
public struct GameTableScreen: View {
    @State private var lobby: Lobby
    @State private var controller: GameController?
    @State private var profile: ProfileStore
    @State private var isEditingProfile = false

    public init() {
        let resetProfile = ProcessInfo.processInfo.arguments.contains("-holdemResetProfile")
        _lobby = State(initialValue: DemoLobby.emptyLobby)
        _profile = State(initialValue: ProfileStore(resetProfile: resetProfile))
    }

    public var body: some View {
        ZStack {
            if !profile.hasProfile || isEditingProfile {
                ProfileSetupView(name: profile.name,
                                 avatar: profile.avatar,
                                 onSave: saveProfile,
                                 onCancel: profileSetupCancelAction)
            } else if let controller {
                DemoGameTable(controller: controller)
            } else {
                DemoLobby(lobby: $lobby,
                          profileName: profile.name,
                          profileAvatar: profile.avatar,
                          onEditProfile: editProfile) {
                    withAnimation(.tableSnap) { controller = GameController(lobby: lobby) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private var profileSetupCancelAction: (() -> Void)? {
        guard profile.hasProfile else { return nil }
        return { cancelProfileEdit() }
    }

    private func saveProfile(name: String, avatar: String) {
        let hadProfile = profile.hasProfile
        profile.save(name: name, avatar: avatar)
        isEditingProfile = false
        if !hadProfile {
            lobby = DemoLobby.emptyLobby
        }
    }

    private func editProfile() {
        withAnimation(.tableSnap) { isEditingProfile = true }
    }

    private func cancelProfileEdit() {
        withAnimation(.tableSnap) { isEditingProfile = false }
    }
}

struct WinningsFly: Equatable {
    let amount: Int
    let toHero: Bool
    let id: Int
}
