import Foundation
import Messages
import GameCore

extension MessagesViewController {
    func heroID(_ conversation: MSConversation) -> String {
        conversation.localParticipantIdentifier.uuidString
    }

    func render(conversation: MSConversation) {
        let hero = heroID(conversation)
        let selectedMessage = MessagePayloads.selectedTableMessage(in: conversation)
        let message: TableMessage?
        switch selectedMessage {
        case .none:
            message = nil
        case .invalidPayload:
            tableRenderer.showInvalidPayload()
            return
        case .message(let decoded):
            message = decoded
        }

        guard profile.hasProfile else {
            renderProfileSetup()
            return
        }

        if let message {
            switch revisionStore.freshness(of: message.revision) {
            case .current:
                revisionStore.remember(message.revision)
            case .stale:
                tableRenderer.showStale(message)
                return
            }
        }

        switch message {
        case .none:
            tableRenderer.showStart(
                name: profile.name,
                avatar: profile.avatar,
                onStart: { [weak self] in self?.createLobby(conversation: conversation) },
                onEditProfile: { [weak self] in self?.renderProfileSetup(isEditingExistingProfile: true) }
            )
        case .lobby(let lobby):
            renderLobby(lobby, hero: hero, conversation: conversation)
        case .game(let state):
            renderGame(state, hero: hero, conversation: conversation)
        }
    }

    func renderProfileSetup(isEditingExistingProfile: Bool = false) {
        isEditingProfile = isEditingExistingProfile
        let canCancel = isEditingExistingProfile && profile.hasProfile
        let rerenderActiveConversation: () -> Void = { [weak self] in
            if let conversation = self?.activeConversation {
                self?.render(conversation: conversation)
            }
        }
        tableRenderer.showProfileSetup(
            name: profile.name,
            avatar: profile.avatar,
            onSave: { [weak self] name, avatar in
                self?.profile.save(name: name, avatar: avatar)
                self?.isEditingProfile = false
                rerenderActiveConversation()
            },
            onCancel: canCancel ? { [weak self] in
                self?.isEditingProfile = false
                rerenderActiveConversation()
            } : nil
        )
    }

    func renderLobby(_ lobby: Lobby, hero: String, conversation: MSConversation) {
        tableRenderer.showLobby(
            lobby,
            hero: hero,
            name: profile.name,
            avatar: profile.avatar,
            onJoin: { [weak self] in self?.lobbyJoin(lobby, conversation: conversation) },
            onToggleReady: { [weak self] in self?.lobbyToggleReady(lobby, conversation: conversation) },
            onLeave: { [weak self] in self?.leaveLobby(lobby, conversation: conversation) },
            onEditProfile: { [weak self] in self?.renderProfileSetup(isEditingExistingProfile: true) }
        )
    }

    func renderGame(_ state: GameState, hero: String, conversation: MSConversation) {
        let now = Date()
        var state = state
        state.resolveTimeout(now: now)
        tableRenderer.showGame(
            state,
            hero: hero,
            now: now,
            name: profile.name,
            avatar: profile.avatar,
            onJoin: { [weak self] in self?.joinGame(state, conversation: conversation) },
            onEditJoinProfile: { [weak self] in self?.renderProfileSetup(isEditingExistingProfile: true) },
            onAction: { [weak self] in self?.commit($0, on: state, conversation: conversation) },
            onDealNext: { [weak self] in self?.dealNextHand(from: state, conversation: conversation) },
            onLeave: { [weak self] in self?.leaveGame(state, conversation: conversation) }
        )
    }
}
