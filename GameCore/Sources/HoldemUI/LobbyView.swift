import SwiftUI
import GameCore

/// Pre-game lobby. Character and handle setup happen before this screen via the
/// locally saved profile.
public struct LobbyView: View {
    private let lobby: Lobby
    private let localID: String
    private let onOperation: (TableOperation) -> Void
    /// Adds a local pass-and-play seat; nil in the iMessage app.
    private let onAddPlayer: (() -> Void)?

    private var isSeated: Bool { lobby.seat(id: localID) != nil }
    private var canStart: Bool { isSeated && lobby.seats.count >= 2 }

    public init(lobby: Lobby, localID: String,
                onOperation: @escaping (TableOperation) -> Void,
                onAddPlayer: (() -> Void)? = nil) {
        self.lobby = lobby
        self.localID = localID
        self.onOperation = onOperation
        self.onAddPlayer = onAddPlayer
    }

    public var body: some View {
        ScrollView { lobbyContent }
            .safeAreaInset(edge: .bottom) {
                lobbyActions
                    .padding(.bottom, 18)
                    .background(Theme.background)
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private var lobbyContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("Table")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text("\(lobby.seats.count)/\(lobby.maxPlayers) players")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.top, 12)

            VStack(spacing: 10) {
                ForEach(lobby.seats) { seat in
                    LobbySeatRow(seat: seat, isLocal: seat.id == localID)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    @ViewBuilder
    private var lobbyActions: some View {
        VStack(spacing: 12) {
            PrimaryActionButton(
                title: "Start game",
                isDisabled: !canStart,
                accessibilityID: HoldemAccessibility.Lobby.startGame,
                action: {
                    onOperation(.startGame(
                        seed: UInt64.random(in: .min ... .max),
                        turnDuration: TurnClock.defaultDuration
                    ))
                }
            )

            if isSeated, let onAddPlayer, !lobby.isFull {
                Button(action: onAddPlayer) {
                    Label("Add player", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(HoldemAccessibility.Lobby.addPlayer)
            }

            if isSeated {
                LeaveTableButton(
                    consequence: "You will give up your seat in the lobby.",
                    style: .text,
                    accessibilityID: HoldemAccessibility.Lobby.leave,
                    confirmAccessibilityID: HoldemAccessibility.Lobby.confirmLeave,
                    cancelAccessibilityID: HoldemAccessibility.Lobby.cancelLeave,
                    action: { onOperation(.leaveLobby) }
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }
}

private struct LobbySeatRow: View {
    let seat: LobbySeat
    let isLocal: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(seat.avatar).font(.system(size: 30))
            Text(seat.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .stableOneLineText(alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .controlSurface(stroke: isLocal ? Theme.accent.opacity(0.8) : .clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLocal ? "\(seat.name), your seat" : seat.name)
        .accessibilityIdentifier(isLocal ? HoldemAccessibility.Lobby.localSeat : "")
    }
}
