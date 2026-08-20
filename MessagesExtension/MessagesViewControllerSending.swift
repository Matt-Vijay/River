import Foundation
import Messages
import GameCore

extension MessagesViewController {
    func send(_ kind: TableOperation, on message: TableMessage,
              conversation: MSConversation) {
        guard let sourceMessage = displayedSourceMessage(in: conversation),
              MessagePayloads.revision(from: sourceMessage) == message.revision else {
            showStale(message)
            return
        }
        if case .leaveLobby = kind { lobbySeatIntent = nil }
        commit(
            kind,
            on: message,
            latestRevision: revisionStore.latest(for: message.revision.tableID),
            replacing: sourceMessage,
            conversation: conversation,
            dismissAfterSend: shouldDismiss(after: kind)
        )
    }

    func createLobby(profile: PlayerProfile, conversation: MSConversation) {
        commit(
            .joinLobby(name: profile.name, avatar: profile.avatar),
            on: .lobby(Lobby()),
            latestRevision: nil,
            replacing: nil,
            conversation: conversation,
            dismissAfterSend: true
        )
    }

    private func commit(_ kind: TableOperation, on message: TableMessage,
                        latestRevision: TableRevision?, replacing sourceMessage: MSMessage?,
                        conversation: MSConversation, dismissAfterSend: Bool) {
        guard activeSend == nil else { return }

        switch message.committing(
            kind,
            actorID: heroID(conversation),
            latestRevision: latestRevision,
            now: Date()
        ) {
        case .applied(let next):
            deliver(
                next,
                recoveringFrom: message,
                replacing: sourceMessage,
                in: conversation,
                dismissAfterSend: dismissAfterSend
            )
        case .unchanged:
            render(conversation: conversation)
        case .rejected(let reason):
            showStale(message, context: .rejectedAction(reason))
        }
    }

    private func deliver(_ message: TableMessage, recoveringFrom recoveryMessage: TableMessage,
                         replacing sourceMessage: MSMessage?, in conversation: MSConversation,
                         dismissAfterSend: Bool) {
        let outgoingMessage: MSMessage
        do {
            outgoingMessage = try MessagePayloads.makeMessage(
                for: message,
                replacing: sourceMessage
            )
        } catch {
            let error = error as NSError
            NSLog("River payload encode failed: %@/%ld", error.domain, error.code)
            showStale(recoveryMessage, context: .encodingFailed)
            return
        }

        let send = ActiveSend(
            sentRevision: message.revision,
            recoveryMessage: recoveryMessage,
            outgoingMessage: outgoingMessage,
            conversation: conversation,
            dismissAfterSend: dismissAfterSend
        )
        activeSend = send
        rootHost.setInteractionEnabled(false)
        render(conversation: conversation)
        scheduleTimeout(for: send.id)

        conversation.send(outgoingMessage) { [weak self] error in
            DispatchQueue.main.async {
                self?.finishSend(id: send.id, error: error)
            }
        }
    }

    func acknowledgeActiveSend(with message: MSMessage) -> Bool {
        guard let send = activeSend,
              MessagePayloads.revision(from: message) == send.sentRevision else { return false }
        finishSend(id: send.id, error: nil)
        return true
    }

    private func finishSend(id: UUID, error: Error?) {
        guard let send = activeSend, send.id == id else { return }
        finishSendActivity()
        activeSend = nil

        guard activeConversation === send.conversation else { return }
        if let error {
            let error = error as NSError
            NSLog("River transport send failed: %@/%ld", error.domain, error.code)
            if supersedes(sourceMessageOverride, baseline: send.outgoingMessage) {
                render(conversation: send.conversation)
            } else {
                showStale(send.recoveryMessage, context: .sendFailed)
            }
            return
        }

        let wasSuperseded = supersedes(sourceMessageOverride, baseline: send.outgoingMessage)
        revisionStore.observe(send.sentRevision)
        if wasSuperseded {
            rootHost.resumeAutomaticRendering()
            render(conversation: send.conversation)
            return
        }
        sourceMessageOverride = send.outgoingMessage

        if send.dismissAfterSend {
            dismissCurrentSurface()
        } else if !rootHost.isProfile {
            rootHost.resumeAutomaticRendering()
            render(conversation: send.conversation)
        }
    }

    func clearActiveSend() {
        finishSendActivity()
        activeSend = nil
    }

    private func finishSendActivity() {
        sendTimeoutWorkItem?.cancel()
        sendTimeoutWorkItem = nil
        rootHost.setInteractionEnabled(true)
    }

    private func scheduleTimeout(for id: UUID) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.finishSend(
                id: id,
                error: NSError(domain: "River.MessagesTransport", code: 1)
            )
        }
        sendTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sendTimeout, execute: workItem)
    }

    private func shouldDismiss(after operation: TableOperation) -> Bool {
        switch operation {
        case .leaveLobby, .gameAction, .resolveTimeout, .leaveGame, .dealNextHand:
            true
        case .joinLobby, .startGame, .joinGame:
            false
        }
    }
}
