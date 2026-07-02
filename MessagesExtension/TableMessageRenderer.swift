import Foundation
import Messages
import SwiftUI
import GameCore
import HoldemUI

struct TableMessageRenderer {
    var rootHost: SwiftUIRootHost
    var presentationStyle: () -> MSMessagesAppPresentationStyle
    var requestExpandedPresentation: () -> Void

    func showStart(name: String, avatar: String,
                   onStart: @escaping () -> Void,
                   onEditProfile: @escaping () -> Void) {
        rootHost.setRoot(StartGameView(profileName: name, profileAvatar: avatar,
                                       onStart: onStart,
                                       onEditProfile: onEditProfile))
    }

    func showProfileSetup(name: String, avatar: String,
                          onSave: @escaping (String, String) -> Void,
                          onCancel: (() -> Void)? = nil) {
        if presentationStyle() == .compact {
            requestExpandedPresentation()
        }
        rootHost.setRoot(ProfileSetupView(name: name,
                                          avatar: avatar,
                                          onSave: onSave,
                                          onCancel: onCancel))
    }

    func showLobby(_ lobby: Lobby, hero: String,
                   name: String, avatar: String,
                   onJoin: @escaping () -> Void,
                   onToggleReady: @escaping () -> Void,
                   onLeave: @escaping () -> Void,
                   onEditProfile: @escaping () -> Void) {
        rootHost.setRoot(
            LobbyView(
                lobby: lobby, localID: hero,
                profileName: name,
                profileAvatar: avatar,
                onJoin: onJoin,
                onToggleReady: onToggleReady,
                onLeave: onLeave,
                onEditProfile: onEditProfile
            )
        )
    }

    func showGame(_ state: GameState, hero: String, now: Date,
                  name: String, avatar: String,
                  onJoin: @escaping () -> Void,
                  onEditJoinProfile: @escaping () -> Void,
                  onAction: @escaping (PlayerAction) -> Void,
                  onDealNext: @escaping () -> Void,
                  onLeave: @escaping () -> Void) {
        let seated = state.player(id: hero)
        let summary = GamePayload.summary(for: state)
        if state.isGameOver {
            rootHost.setRoot(GameOverView(summary: summary))
        } else if seated == nil || seated?.hasLeft == true {
            rootHost.setRoot(
                JoinGameView(summary: summary,
                             profileName: name,
                             profileAvatar: avatar,
                             onJoin: onJoin,
                             onEditProfile: onEditJoinProfile)
            )
        } else if presentationStyle() == .compact {
            rootHost.setRoot(
                CompactSummaryView(summary: summary,
                                   onOpen: requestExpandedPresentation)
            )
        } else {
            rootHost.setRoot(
                PokerTableView(
                    state: state,
                    heroID: hero,
                    now: now,
                    onAction: onAction,
                    onDealNext: onDealNext,
                    onLeave: onLeave
                )
            )
        }
    }

    func showStale(_ message: TableMessage,
                   context: StaleTablePresentation.Context = .olderMessage) {
        rootHost.setRoot(StaleTableView(summary: GamePayload.summary(for: message),
                                        context: context))
    }

    func showInvalidPayload() {
        rootHost.setRoot(StaleTableView(summary: "Invalid table message",
                                        context: .invalidPayload))
    }
}
