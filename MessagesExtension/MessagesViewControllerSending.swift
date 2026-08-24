import Foundation
import Messages
import GameCore

extension MessagesViewController {
    func authenticatedTableMessage(
        from source: MSMessage?,
        in conversation: MSConversation,
        predecessor explicitPredecessor: TableMessage? = nil
    ) -> SelectedTableMessage {
        guard let source else { return .none }
        let isOptimisticLocal = source === optimisticLocalMessage
            || source === activeSend?.outgoingMessage
        let storedPredecessor: TableMessage?
        if let explicitPredecessor {
            storedPredecessor = explicitPredecessor
        } else if source === activeSend?.outgoingMessage {
            storedPredecessor = activeSend?.recoveryMessage
        } else if source === sourceMessageOverride {
            storedPredecessor = sourceVerificationPredecessor
        } else {
            storedPredecessor = nil
        }
        return MessagePayloads.tableMessage(
            from: source,
            authenticatingOptimisticLocalParticipant: isOptimisticLocal
                ? conversation.localParticipantIdentifier
                : nil,
            predecessor: storedPredecessor
        )
    }

    func send(_ kind: TableOperation, on message: TableMessage,
              conversation: MSConversation) {
        guard let sourceMessage = displayedSourceMessage(in: conversation),
              case .message(let authenticatedMessage) = authenticatedTableMessage(
                  from: sourceMessage,
                  in: conversation
              ),
              authenticatedMessage == message else {
            showStale(message)
            return
        }
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
        guard activeSend == nil,
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
        let outgoingMessage: MSMessage
        do {
            outgoingMessage = try MessagePayloads.makeMessage(
                for: message,
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
            sentRevision: message.revision,
            recoveryMessage: recoveryMessage,
            outgoingMessage: outgoingMessage,
            conversation: conversation,
            dismissAfterSend: dismissAfterSend
        )
        activeSend = send
        optimisticLocalMessage = outgoingMessage
        render(conversation: conversation)
        rootHost.setInteractionEnabled(false)
        scheduleTimeout(for: send.id)

        conversation.send(outgoingMessage) { [weak self] error in
            DispatchQueue.main.async {
                self?.finishSend(id: send.id, error: error, confirmedMessage: nil)
            }
        }
    }

    func acknowledgeActiveSend(with message: MSMessage) -> Bool {
        guard let send = activeSend,
              message.session == send.outgoingMessage.session,
              message.url == send.outgoingMessage.url,
              case .message(let authenticatedMessage) = authenticatedTableMessage(
                  from: message,
                  in: send.conversation,
                  predecessor: send.recoveryMessage
              ),
              authenticatedMessage.revision == send.sentRevision else { return false }
        finishSend(id: send.id, error: nil, confirmedMessage: message)
        return true
    }

    private func finishSend(id: UUID, error: Error?, confirmedMessage: MSMessage?) {
        guard let send = activeSend, send.id == id else { return }
        finishSendActivity()
        activeSend = nil

        guard activeConversation === send.conversation else { return }
        if let error {
            if optimisticLocalMessage === send.outgoingMessage {
                optimisticLocalMessage = nil
            }
            let error = error as NSError
            NSLog("River transport send failed: %@/%ld", error.domain, error.code)
            if supersedes(
                sourceMessageOverride,
                baseline: send.outgoingMessage,
                in: send.conversation
            ) {
                render(conversation: send.conversation)
            } else {
                showStale(send.recoveryMessage, context: .sendFailed)
            }
            return
        }

        let wasSuperseded = supersedes(
            sourceMessageOverride,
            baseline: send.outgoingMessage,
            in: send.conversation
        )
        revisionStore.observe(send.sentRevision)
        if wasSuperseded {
            rootHost.resumeAutomaticRendering()
            render(conversation: send.conversation)
            return
        }
        let deliveredMessage = confirmedMessage ?? send.outgoingMessage
        sourceMessageOverride = deliveredMessage
        sourceVerificationPredecessor = send.recoveryMessage
        optimisticLocalMessage = confirmedMessage == nil ? deliveredMessage : nil

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
