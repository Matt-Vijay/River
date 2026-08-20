import UIKit
import Messages
import GameCore
import HoldemUI

/// The iMessage extension entry point. Decodes the table message (lobby or live
/// game) from the selected message, hosts the matching SwiftUI screen, and on
/// each action sends an updated message that collapses into the same bubble.
///
/// Transport model: state travels entirely in `MSMessage.url`; no server.
/// Each user action sends one replacement message. Turn timeouts are resolved
/// explicitly by any seated client after the shared deadline.
final class MessagesViewController: MSMessagesAppViewController {
    struct ActiveSend {
        let id = UUID()
        let sentRevision: TableRevision
        let recoveryMessage: TableMessage
        let outgoingMessage: MSMessage
        let conversation: MSConversation
        let dismissAfterSend: Bool
    }

    static let sendTimeout: TimeInterval = 30

    lazy var rootHost = SwiftUIRootHost(parent: self)
    let profile = ProfileStore()
    let revisionStore = LatestRevisionStore()
    var sourceMessageOverride: MSMessage?
    var lobbySeatIntent: String?
    var activeConversationID: ObjectIdentifier?
    var activeSend: ActiveSend?
    var sendTimeoutWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        observeActiveConversation(conversation)
    }

    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        observeActiveConversation(conversation)
        reconcileSourceOverrides(in: conversation)
        guard rootHost.allowsAutomaticRendering else { return }
        render(conversation: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        guard let conversation = activeConversation else { return }
        observeActiveConversation(conversation)
        guard rootHost.allowsAutomaticRendering else { return }
        render(conversation: conversation)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        observeActiveConversation(conversation)
        // `selectedMessage` can still be nil while this callback is running.
        // Render the message Messages actually handed us instead of racing the
        // conversation property and falling back to the new-table screen.
        sourceMessageOverride = message
        let selected = MessagePayloads.tableMessage(from: message)
        if case .message(.lobby(let lobby)) = selected {
            lobbySeatIntent = lobby.tableID
        } else {
            lobbySeatIntent = nil
        }
        if case .message = selected, presentationStyle == .compact {
            requestPresentationStyle(.expanded)
        }
        render(conversation: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        observeActiveConversation(conversation)
        guard shouldDisplayReceived(message, in: conversation) else { return }
        sourceMessageOverride = message
        if acknowledgeActiveSend(with: message) { return }
        // Receipt tracks the newest table; only selecting its bubble claims a seat.
        guard rootHost.allowsAutomaticRendering else { return }
        render(conversation: conversation)
    }

    func dismissCurrentSurface() {
        rootHost.resumeAutomaticRendering()
        dismiss()
    }

    private func observeActiveConversation(_ conversation: MSConversation) {
        let conversationID = ObjectIdentifier(conversation)
        guard activeConversationID != conversationID else { return }
        if let activeSend,
           activeSend.conversation !== conversation {
            clearActiveSend()
        }
        activeConversationID = conversationID
        sourceMessageOverride = nil
        lobbySeatIntent = nil
        if rootHost.isRecovery { rootHost.resumeAutomaticRendering() }
        rootHost.invalidateIdentity()
    }

    private func reconcileSourceOverrides(in conversation: MSConversation) {
        guard let source = sourceMessageOverride,
              let selected = conversation.selectedMessage else { return }
        let sourcePayload = MessagePayloads.tableMessage(from: source)
        let selectedPayload = MessagePayloads.tableMessage(from: selected)
        if case .message(let sourceMessage) = sourcePayload,
           case .message(let selectedMessage) = selectedPayload {
            guard sourceMessage.revision.tableID == selectedMessage.revision.tableID,
                  sourceMessage.revision.isOlder(than: selectedMessage.revision) else { return }
        } else if case .message = sourcePayload,
                  source.session != nil,
                  source.session == selected.session {
            return
        }
        if source.session == nil, selected.session == nil, source.url == selected.url { return }
        self.sourceMessageOverride = nil
    }
}
