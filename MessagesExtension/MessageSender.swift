import Foundation
import Messages
import GameCore

enum MessageSendResult {
    case sent
    case encodingFailed(Error)
}

final class MessageSender {
    private let revisionStore: LatestRevisionStore
    private let onSendSuccess: (TableMessage) -> Void
    private let onSendFailure: (TableMessage, Error) -> Void

    init(revisionStore: LatestRevisionStore,
         onSendSuccess: @escaping (TableMessage) -> Void = { _ in },
         onSendFailure: @escaping (TableMessage, Error) -> Void = { _, _ in }) {
        self.revisionStore = revisionStore
        self.onSendSuccess = onSendSuccess
        self.onSendFailure = onSendFailure
    }

    func revisionTracker() -> TableRevisionTracker {
        revisionStore.snapshot()
    }

    func send(_ message: TableMessage, in conversation: MSConversation) -> MessageSendResult {
        let outgoing: MSMessage
        do {
            outgoing = try MessagePayloads.makeMessage(for: message, in: conversation)
        } catch {
            return .encodingFailed(error)
        }

        conversation.send(outgoing) { error in
            if let error {
                NSLog("River send failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onSendFailure(message, error)
                }
            } else {
                DispatchQueue.main.async {
                    self.revisionStore.remember(message.revision)
                    self.onSendSuccess(message)
                }
            }
        }
        return .sent
    }
}
