import Foundation
import SwiftUI
import GameCore

/// Local pass-and-play. Remote multiplayer runs in the Messages extension.
public struct GameTableScreen: View {
    private struct RevealedHand: Equatable {
        let number: Int
        let playerID: String
    }

    private static let localPlayerID = "local-player"

    @State private var table: TableMessage
    @State private var profile: PlayerProfile?
    @State private var revealedHand: RevealedHand?
    @Environment(\.scenePhase) private var scenePhase

    private let profileStore: ProfileStore

    public init(resetProfile: Bool = false) {
        let profileStore = ProfileStore(resetProfile: resetProfile)
        let profile = profileStore.configuredProfile
        self.profileStore = profileStore
        _table = State(initialValue: Self.newTable(profile: profile))
        _profile = State(initialValue: profile)
        _revealedHand = State(initialValue: nil)
    }

    public var body: some View {
        Group {
            if profile == nil {
                ProfileSetupView(onSave: saveProfile)
            } else {
                switch table {
                case .game(let state):
                    gameTable(state)
                case .lobby(let lobby):
                    LobbyView(
                        lobby: lobby,
                        localID: Self.localPlayerID,
                        onOperation: {
                            apply($0, actorID: Self.localPlayerID)
                        },
                        onAddPlayer: addPlayer
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                revealedHand = nil
            }
        }
    }

    private func saveProfile(_ configuredProfile: PlayerProfile) {
        profileStore.save(configuredProfile)
        profile = configuredProfile
        table = Self.newTable(profile: configuredProfile)
    }

    private func addPlayer() {
        guard case .lobby(let lobby) = table else { return }
        let number = lobby.seats.count
        let guestID = "guest\(number)"
        let avatars = CharacterAvatars.all
        apply(
            .joinLobby(name: "Guest \(number)", avatar: avatars[number % avatars.count]),
            actorID: guestID
        )
    }

    private func apply(_ operation: TableOperation, actorID: String) {
        if case .applied(let next) = table.committing(
            operation,
            actorID: actorID,
            now: Date()
        ) {
            table = next
        }
    }

    private func gameTable(_ state: GameState) -> some View {
        Group {
            if state.isGameOver {
                GameOverView(summary: GamePayload.summary(for: state), onNewTable: startNewTable)
            } else if let context = PokerTableContext(
                state: state,
                heroID: state.currentPlayer?.id
                    ?? state.playersEligibleForNextHand.first?.id
                    ?? ""
            ) {
                if !context.state.isHandComplete,
                   revealedHand != RevealedHand(
                       number: context.state.handNumber,
                       playerID: context.hero.id
                   ) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        handoffContent(context, at: timeline.date)
                            .overlay(alignment: .topLeading) {
                                LeaveTableButton(
                                    consequence: context.leaveConsequence,
                                    action: { apply(.leaveGame, actorID: context.hero.id) }
                                )
                            }
                    }
                } else {
                    PokerTableView(
                        context: context,
                        onOperation: { apply($0, actorID: context.hero.id) }
                    )
                }
            } else {
                GameOverView(summary: "No active seat remains at this table.",
                             onNewTable: startNewTable)
            }
        }
        .id(state.tableID)
    }

    private func reveal(_ context: PokerTableContext) {
        revealedHand = RevealedHand(
            number: context.state.handNumber,
            playerID: context.hero.id
        )
    }

    private func handoffContent(_ context: PokerTableContext, at date: Date) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text(context.hero.avatar)
                    .font(.system(size: 56))
                Text("\(context.hero.name)'s turn")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(context.hero.name)'s turn. Hand hidden.")
            .turnClockAccessibilityValue(
                startedAt: context.state.turnStartedAt ?? date,
                duration: context.state.turnDuration
            )
            .accessibilityIdentifier(HoldemAccessibility.Table.handoff)

            if context.state.isTurnExpired(at: date) {
                PrimaryActionButton(
                    title: "Resolve turn",
                    systemImage: "clock.badge.exclamationmark",
                    accessibilityID: HoldemAccessibility.Table.resolveTimeout,
                    action: { apply(.resolveTimeout, actorID: context.hero.id) }
                )
            } else {
                PrimaryActionButton(
                    title: "View hand",
                    systemImage: "eye.fill",
                    accessibilityID: HoldemAccessibility.Table.revealHand,
                    action: { reveal(context) }
                )
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private func startNewTable() {
        revealedHand = nil
        table = Self.newTable(profile: profile)
    }

    private static func newTable(profile: PlayerProfile?) -> TableMessage {
        let table = TableMessage.lobby(Lobby())
        guard let profile,
              case .applied(let joined) = table.committing(
                .joinLobby(name: profile.name, avatar: profile.avatar),
                actorID: localPlayerID
              ) else { return table }
        return joined
    }

}
