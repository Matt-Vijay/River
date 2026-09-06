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
        let outgoing: MessageSource
        let conversation: MSConversation
        let dismissAfterSend: Bool
    }

    static let sendTimeout: TimeInterval = 30

    lazy var rootHost = SwiftUIRootHost(parent: self)
    let profile = ProfileStore()
    let history = TableHistory()
    var sourceOverride: MessageSource?
    var lobbySeatIntent: String?
    var activeConversationID: ObjectIdentifier?
    var activeSend: ActiveSend?
    var sendTimeoutWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        observeActiveConversation(conversation)
        if let selectedMessage = conversation.selectedMessage {
            captureSelection(selectedMessage, in: conversation)
        }
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
        let selected = captureSelection(message, in: conversation)
        if case .message = selected, presentationStyle == .compact {
            requestPresentationStyle(.expanded)
        }
        render(conversation: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        observeActiveConversation(conversation)
        let displayed = displayedSource(in: conversation)
        let received = MessageSource(receiving: message,
                                     localID: conversation.localParticipantIdentifier.uuidString,
                                     history: history,
                                     predecessor: displayed?.content.decodedMessage)
        guard received.shouldDisplay(replacing: displayed) else { return }
        // Receiving can refresh what is displayed, but must never reuse a
        // selection-only seat intent and emit a mutation as a side effect.
        lobbySeatIntent = nil
        sourceOverride = received
        if acknowledgeActiveSend(with: received) { return }
        // Receipt tracks the newest table; only selecting its bubble claims a seat.
        guard rootHost.allowsAutomaticRendering else { return }
        render(conversation: conversation)
    }

    func dismissCurrentSurface() {
        rootHost.resumeAutomaticRendering()
        dismiss()
    }

    @discardableResult
    private func captureSelection(
        _ message: MSMessage,
        in conversation: MSConversation
    ) -> SelectedTableMessage {
        let displayed = displayedSource(in: conversation)
        let selected: MessageSource
        if let displayed, displayed.message === message, case .message = displayed.content {
            selected = displayed
        } else {
            selected = MessageSource(receiving: message,
                                     localID: conversation.localParticipantIdentifier.uuidString,
                                     history: history,
                                     predecessor: displayed?.content.decodedMessage)
        }
        sourceOverride = selected
        if case .message(.lobby(let lobby)) = selected.content {
            lobbySeatIntent = lobby.tableID
        } else {
            lobbySeatIntent = nil
        }
        return selected.content
    }

    private func observeActiveConversation(_ conversation: MSConversation) {
        let conversationID = ObjectIdentifier(conversation)
        guard activeConversationID != conversationID else { return }
        if let activeSend,
           activeSend.conversation !== conversation {
            clearActiveSend()
        }
        activeConversationID = conversationID
        sourceOverride = nil
        lobbySeatIntent = nil
        if rootHost.isRecovery { rootHost.resumeAutomaticRendering() }
        rootHost.invalidateIdentity()
    }

    private func reconcileSourceOverrides(in conversation: MSConversation) {
        guard let source = sourceOverride,
              let message = conversation.selectedMessage,
              source.message !== message else { return }
        let selected = MessageSource(receiving: message,
                                     localID: conversation.localParticipantIdentifier.uuidString,
                                     history: history,
                                     predecessor: source.content.decodedMessage)
        if let previous = source.revision, let next = selected.revision {
            guard previous.tableID == next.tableID, previous.isOlder(than: next) else { return }
        } else if case .message = source.content,
                  source.message.session != nil,
                  source.message.session == message.session {
            return
        }
        if source.message.session == nil, message.session == nil,
           source.message.url == message.url { return }
        sourceOverride = selected
    }
}
