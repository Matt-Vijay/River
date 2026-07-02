import SwiftUI
import GameCore

/// Pre-game lobby: see who's seated and ready up. Character and handle setup
/// happen before this screen via the locally saved profile.
public struct LobbyView: View {
    public let lobby: Lobby
    public let localID: String
    public var profileName: String?
    public var profileAvatar: String?
    public var onJoin: () -> Void
    public var onToggleReady: () -> Void
    /// Shown when you're seated: leave the table.
    public var onLeave: (() -> Void)?
    /// Edit the saved local profile before taking a seat.
    public var onEditProfile: (() -> Void)?
    /// Demo-only: adds a stand-in player on one device (nil in the real iMessage app).
    public var onAddTestPlayer: (() -> Void)?

    public init(lobby: Lobby, localID: String,
                profileName: String? = nil,
                profileAvatar: String? = nil,
                onJoin: @escaping () -> Void,
                onToggleReady: @escaping () -> Void,
                onLeave: (() -> Void)? = nil,
                onEditProfile: (() -> Void)? = nil,
                onAddTestPlayer: (() -> Void)? = nil) {
        self.lobby = lobby
        self.localID = localID
        self.profileName = profileName
        self.profileAvatar = profileAvatar
        self.onJoin = onJoin
        self.onToggleReady = onToggleReady
        self.onLeave = onLeave
        self.onEditProfile = onEditProfile
        self.onAddTestPlayer = onAddTestPlayer
    }

    private var localSeat: LobbySeat? { lobby.seat(id: localID) }
    private var isJoined: Bool { localSeat != nil }

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                LobbyHeader(lobby: lobby)
                LobbySeatList(seats: lobby.seats, localID: localID)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            LobbyActions(
                isJoined: isJoined,
                isReady: localSeat?.isReady ?? false,
                isFull: lobby.isFull,
                profileName: isJoined ? nil : profileName,
                profileAvatar: isJoined ? nil : profileAvatar,
                onJoin: onJoin,
                onToggleReady: onToggleReady,
                onLeave: onLeave,
                onEditProfile: isJoined ? nil : onEditProfile,
                onAddTestPlayer: onAddTestPlayer
            )
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .background(Theme.background)
        }
        .animation(.tableSnap, value: lobby)
    }
}

#Preview("Lobby") {
    LobbyView(
        lobby: Lobby(seats: [
            LobbySeat(id: "a", name: "dante", avatar: "🧑🏿", isReady: true),
            LobbySeat(id: "you", name: "you", avatar: "🦊", isReady: false),
            LobbySeat(id: "c", name: "verbice", avatar: "🐱", isReady: true),
        ]),
        localID: "you", onJoin: {}, onToggleReady: {}
    )
}
