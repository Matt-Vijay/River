import SwiftUI
import GameCore

struct DemoLobby: View {
    static let localID = "local-player"

    static var emptyLobby: Lobby {
        Lobby()
    }

    @Binding var lobby: Lobby
    let profileName: String
    let profileAvatar: String
    let onEditProfile: () -> Void
    let onStart: () -> Void

    var body: some View {
        LobbyView(
            lobby: lobby, localID: Self.localID,
            profileName: profileName,
            profileAvatar: profileAvatar,
            onJoin: joinLocalPlayer,
            onToggleReady: toggleReady,
            onLeave: leaveLocalPlayer,
            onEditProfile: onEditProfile,
            onAddTestPlayer: addTestPlayer
        )
        .transition(.opacity)
    }

    private func joinLocalPlayer() {
        lobby = lobby.adding(id: Self.localID, name: profileName, avatar: profileAvatar)
    }

    private func toggleReady() {
        lobby = lobby.updating(id: Self.localID, isReady: !lobby.isReady(id: Self.localID))
        if lobby.canStart { onStart() }
    }

    private func leaveLocalPlayer() {
        lobby = lobby.removing(id: Self.localID)
    }

    private func addTestPlayer() {
        let n = lobby.seats.count
        let avatars = CharacterAvatars.all
        lobby = lobby
            .adding(id: "guest\(n)", name: "Guest \(n)", avatar: avatars[n % avatars.count])
            .updating(id: "guest\(n)", isReady: true)
    }
}
