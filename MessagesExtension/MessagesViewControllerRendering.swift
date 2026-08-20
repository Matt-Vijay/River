import Messages
import SwiftUI
import GameCore
import HoldemUI

extension MessagesViewController {
    func heroID(_ conversation: MSConversation) -> String {
        profile.playerID(seed: conversation.localParticipantIdentifier.uuidString)
    }

    func render(conversation: MSConversation) {
        guard let configuredProfile = profile.configuredProfile else {
            renderProfileSetup()
            return
        }
        let source = displayedSourceMessage(in: conversation)
        let selectedMessage = MessagePayloads.tableMessage(from: source)
        render(selectedMessage,
               profile: configuredProfile,
               conversation: conversation)
    }

    func displayedSourceMessage(in conversation: MSConversation) -> MSMessage? {
        if let activeSend,
           activeSend.conversation === conversation,
           !supersedes(sourceMessageOverride, baseline: activeSend.outgoingMessage) {
            return activeSend.outgoingMessage
        }
        return sourceMessageOverride ?? conversation.selectedMessage
    }

    func supersedes(_ candidate: MSMessage?, baseline: MSMessage) -> Bool {
        guard let candidateRevision = MessagePayloads.revision(from: candidate),
              let baselineRevision = MessagePayloads.revision(from: baseline) else {
            return false
        }
        return candidateRevision.tableID != baselineRevision.tableID
            || baselineRevision.isOlder(than: candidateRevision)
    }

    func shouldDisplayReceived(_ message: MSMessage, in conversation: MSConversation) -> Bool {
        guard let displayed = displayedSourceMessage(in: conversation) else { return true }
        if let currentRevision = MessagePayloads.revision(from: displayed) {
            guard let incomingRevision = MessagePayloads.revision(from: message) else { return false }
            return incomingRevision.tableID != currentRevision.tableID
                || incomingRevision.isSameOrNewer(than: currentRevision)
        }
        return message.session != nil && message.session == displayed.session
    }

    private func render(_ selectedMessage: SelectedTableMessage,
                        profile configuredProfile: PlayerProfile,
                        conversation: MSConversation) {
        let hero = heroID(conversation)
        switch selectedMessage {
        case .none:
            rootHost.setRoot(
                ConversationNewTableView(onSend: { [weak self] in
                    self?.createLobby(profile: configuredProfile, conversation: conversation)
                }),
                identity: "new-table"
            )
        case .invalidPayload:
            showRecovery(summary: "Invalid table message", context: .invalidPayload)
        case .message(let message):
            let isOptimistic = activeSend?.conversation === conversation
                && activeSend?.sentRevision == message.revision
            if !isOptimistic {
                guard revisionStore.observe(message.revision) else {
                    showStale(message)
                    return
                }
            }

            switch message {
            case .lobby(let lobby):
                if lobbySeatIntent == lobby.tableID {
                    if lobby.seat(id: hero) == nil, !lobby.isFull {
                        send(
                            .joinLobby(name: configuredProfile.name,
                                       avatar: configuredProfile.avatar),
                            on: message,
                            conversation: conversation
                        )
                        return
                    }
                }
                renderLobby(lobby, hero: hero, conversation: conversation)
            case .game(let state):
                lobbySeatIntent = nil
                renderGame(state, hero: hero, profile: configuredProfile,
                           conversation: conversation)
            }
        }
    }

    func renderProfileSetup() {
        setExpandedRoot(
            ProfileSetupView(
                onSave: { [weak self] configuredProfile in
                    self?.profile.save(configuredProfile)
                    guard let self, let conversation = activeConversation else { return }
                    render(conversation: conversation)
                }
            ),
            identity: "profile",
            interruption: .profile
        )
    }

    func renderLobby(_ lobby: Lobby, hero: String, conversation: MSConversation) {
        if presentationStyle == .compact {
            renderCompact(
                summary: GamePayload.summary(for: .lobby(lobby)),
                identity: "compact:lobby:\(lobby.tableID)"
            )
        } else {
            setExpandedRoot(
                LobbyView(
                    lobby: lobby,
                    localID: hero,
                    onOperation: { [weak self] in
                        self?.send($0, on: .lobby(lobby), conversation: conversation)
                    }
                ),
                identity: "lobby:\(lobby.tableID)"
            )
        }
    }

    func renderGame(_ state: GameState, hero: String, profile: PlayerProfile,
                    conversation: MSConversation) {
        let heroPlayer = state.playerIndex(id: hero).map { state.players[$0] }
        let summary = GamePayload.summary(for: state)
        if presentationStyle == .compact {
            renderCompact(summary: summary, identity: "compact:game:\(state.tableID)")
        } else if state.isGameOver {
            setExpandedRoot(
                GameOverView(summary: summary, onNewTable: { [weak self] in
                    self?.createLobby(profile: profile, conversation: conversation)
                }),
                identity: "game-over:\(state.tableID)"
            )
        } else if heroPlayer?.hasLeft != false
                    || (state.isHandComplete && heroPlayer?.stack == 0) {
            let onJoin: (() -> Void)?
            if state.canJoinGame(id: hero) {
                onJoin = { [weak self] in
                    self?.send(
                        .joinGame(name: profile.name, avatar: profile.avatar,
                                  startingStack: Lobby.defaultStartingStack),
                        on: .game(state),
                        conversation: conversation
                    )
                }
            } else {
                onJoin = nil
            }
            setExpandedRoot(
                ConversationGameEntryView(summary: summary, onJoin: onJoin),
                identity: "join:\(state.tableID)"
            )
        } else if let table = PokerTableView(
            state: state,
            heroID: hero,
            onOperation: { [weak self] operation in
                self?.send(operation, on: .game(state), conversation: conversation)
            }
        ) {
            rootHost.setRoot(
                table,
                identity: "game:\(state.tableID)"
            )
        }
    }

    private func renderCompact(summary: String, identity: String) {
        rootHost.setRoot(
            CompactSummaryView(
                summary: summary,
                onOpen: { [weak self] in self?.requestPresentationStyle(.expanded) }
            ),
            identity: identity
        )
    }

    func showStale(_ message: TableMessage,
                   context: StaleTableView.Context = .olderMessage) {
        showRecovery(summary: GamePayload.summary(for: message),
                     context: context,
                     tableID: message.revision.tableID)
    }

    private func showRecovery(summary: String,
                              context: StaleTableView.Context,
                              tableID: String? = nil) {
        setExpandedRoot(
            StaleTableView(summary: summary,
                           context: context,
                           onClose: { [weak self] in self?.dismissCurrentSurface() }),
            identity: "recovery:\(tableID ?? "")",
            interruption: .recovery
        )
    }

    private func setExpandedRoot<Content: View>(
        _ view: Content,
        identity: String,
        interruption: SwiftUIRootHost.Interruption? = nil
    ) {
        if presentationStyle == .compact {
            requestPresentationStyle(.expanded)
        }
        rootHost.setRoot(view, identity: identity, interruption: interruption)
    }
}
