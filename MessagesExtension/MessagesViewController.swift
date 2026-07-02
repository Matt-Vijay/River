import UIKit
import SwiftUI
import Messages
import GameCore
import HoldemUI

/// The iMessage extension entry point. Decodes the table message (lobby or live
/// game) from the selected message, hosts the matching SwiftUI screen, and on
/// each action sends an updated message that collapses into the same bubble.
///
/// Transport model: state travels entirely in `MSMessage.url`; no server.
/// `conversation.send` posts in response to the player's tap. Turn timeouts are
/// resolved lazily by whichever client next loads or acts.
final class MessagesViewController: MSMessagesAppViewController {

    lazy var rootHost = SwiftUIRootHost(parent: self)
    let profile = ProfileStore()
    let tableSettings = MessageTableSettings()
    let revisionStore = LatestRevisionStore()
    lazy var tableRenderer = TableMessageRenderer(
        rootHost: rootHost,
        presentationStyle: { [weak self] in self?.presentationStyle ?? .compact },
        requestExpandedPresentation: { [weak self] in self?.requestPresentationStyle(.expanded) }
    )
    lazy var messageCommitter = TableMessageCommitter(
        messageSender: MessageSender(
            revisionStore: revisionStore,
            onSendSuccess: { [weak self] _ in
                self?.dismiss()
            },
            onSendFailure: { [weak self] message, _ in
                self?.requestPresentationStyle(.expanded)
                self?.tableRenderer.showStale(message, context: .sendFailed)
            }
        )
    )
    lazy var messageActions = TableMessageActions(settings: tableSettings)
    var isEditingProfile = false

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        render(conversation: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        if isEditingProfile || !profile.hasProfile {
            renderProfileSetup(isEditingExistingProfile: isEditingProfile)
        } else if let conversation = activeConversation {
            render(conversation: conversation)
        }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        render(conversation: conversation)
    }
}
