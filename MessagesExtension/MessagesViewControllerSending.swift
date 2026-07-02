import Foundation
import Messages
import GameCore

extension MessagesViewController {
    func send(_ kind: TableOperation.Kind, on message: TableMessage, conversation: MSConversation) {
        handleCommit(
            messageCommitter.applyAndSend(kind, to: message,
                                          actorID: heroID(conversation),
                                          conversation: conversation),
            conversation: conversation
        )
    }

    func send(_ message: TableMessage, conversation: MSConversation) {
        handleCommit(messageCommitter.send(message, conversation: conversation), conversation: conversation)
    }

    func handleCommit(_ result: TableMessageCommitResult, conversation: MSConversation) {
        switch result {
        case .sent:
            break
        case .unchanged:
            dismiss()
        case .stale(let message):
            tableRenderer.showStale(message, context: .rejectedAction())
        case .rejected(let message, let reason):
            tableRenderer.showStale(message, context: .rejectedAction(reason))
        case .encodingFailed(let error):
            NSLog("River payload encode failed: \(error.localizedDescription)")
            switch MessagePayloads.selectedTableMessage(in: conversation) {
            case .message(let message):
                tableRenderer.showStale(message, context: .encodingFailed)
            case .invalidPayload:
                tableRenderer.showInvalidPayload()
            case .none:
                render(conversation: conversation)
            }
        }
    }
}
