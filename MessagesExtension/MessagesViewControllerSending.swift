import Foundation
import Messages
import GameCore

extension MessagesViewController {
    func send(_ kind: TableOperation, on message: TableMessage,
              conversation: MSConversation) {
        guard let source = displayedSource(in: conversation),
              case .message(let authenticatedMessage) = source.content,
              authenticatedMessage == message else {
            showStale(message)
            return
        }
        commit(
            kind,
            on: message,
            latestRevision: history.latest(for: message.revision.tableID),
            replacing: source.message,
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
        guard activeSend == nil, activeConversation === conversation,
              let actor = TableActor(conversation.localParticipantIdentifier.uuidString) else {
            return
        }

        switch TableMutationReceipt.recording(
            kind,
            on: message,
            actor: actor,
            latestRevision: latestRevision,
            at: Date()
        ) {
        case .applied(let next, let receipt):
            deliver(
                next,
                receipt: receipt,
                recoveringFrom: message,
                replacing: sourceMessage,
                in: conversation,
                dismissAfterSend: dismissAfterSend
            )
        case .unchanged:
            render(conversation: conversation)
        case .rejected(let reason):
            showStale(message, context: .rejectedAction(reason))
        case .unrecordable:
            showStale(message, context: .encodingFailed)
        }
    }

    private func deliver(_ message: TableMessage, receipt: TableMutationReceipt,
                         recoveringFrom recoveryMessage: TableMessage,
                         replacing sourceMessage: MSMessage?, in conversation: MSConversation,
                         dismissAfterSend: Bool) {
        let outgoing: MessageSource
        do {
            outgoing = try MessageSource(
                sending: message,
                receipt: receipt,
                replacing: sourceMessage
            )
        } catch {
            let error = error as NSError
            NSLog("River payload encode failed: %@/%ld", error.domain, error.code)
            showStale(recoveryMessage, context: .encodingFailed)
            return
        }

        let send = ActiveSend(
            sentRevision: receipt.resultRevision,
            recoveryMessage: recoveryMessage,
            outgoing: outgoing,
            conversation: conversation,
            dismissAfterSend: dismissAfterSend
        )
        activeSend = send
        render(conversation: conversation)
        rootHost.setInteractionEnabled(false)
        scheduleTimeout(for: send.id)

        conversation.send(outgoing.message) { [weak self, id = send.id] error in
            DispatchQueue.main.async {
                self?.finishSend(id: id, error: error, confirmedMessage: nil)
            }
        }
    }

    func acknowledgeActiveSend(with received: MessageSource) -> Bool {
        guard let send = activeSend,
              received.message.session == send.outgoing.message.session,
              received.message.url == send.outgoing.message.url,
              case .message = received.content,
              received.revision == send.sentRevision else { return false }
        finishSend(id: send.id, error: nil, confirmedMessage: received)
        return true
    }

    private func finishSend(id: UUID, error: Error?, confirmedMessage: MessageSource?) {
        guard let send = activeSend, send.id == id else { return }
        let wasSuperseded = sourceOverride?.supersedes(send.outgoing) == true
        clearActiveSend()

        guard activeConversation === send.conversation else { return }
        if let error {
            if sourceOverride?.message === send.outgoing.message {
                sourceOverride = nil
            }
            let error = error as NSError
            NSLog("River transport send failed: %@/%ld", error.domain, error.code)
            if wasSuperseded {
                rootHost.resumeAutomaticRendering()
                render(conversation: send.conversation)
            } else {
                showStale(send.recoveryMessage, context: .sendFailed)
            }
            return
        }

        history.observe(send.sentRevision)
        if wasSuperseded {
            rootHost.resumeAutomaticRendering()
            render(conversation: send.conversation)
            return
        }
        sourceOverride = confirmedMessage ?? send.outgoing

        if send.dismissAfterSend {
            dismissCurrentSurface()
        } else if !rootHost.isProfile {
            rootHost.resumeAutomaticRendering()
            render(conversation: send.conversation)
        }
    }

    func clearActiveSend() {
        activeSend = nil
        sendTimeoutWorkItem?.cancel()
        sendTimeoutWorkItem = nil
        rootHost.setInteractionEnabled(true)
    }

    private func scheduleTimeout(for id: UUID) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.finishSend(
                id: id,
                error: NSError(domain: "River.MessagesTransport", code: 1),
                confirmedMessage: nil
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
