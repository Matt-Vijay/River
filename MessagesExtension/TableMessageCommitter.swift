import Foundation
import Messages
import GameCore

enum TableMessageCommitResult {
    case sent
    case unchanged
    case stale(TableMessage)
    case rejected(TableMessage, TableOperationRejection)
    case encodingFailed(Error)
}

struct TableOperationContext {
    var makeID: () -> String
    var now: () -> Date

    static let live = TableOperationContext(
        makeID: { UUID().uuidString },
        now: Date.init
    )
}

final class TableMessageCommitter {
    private let messageSender: MessageSender
    private let operationContext: TableOperationContext

    init(messageSender: MessageSender, operationContext: TableOperationContext = .live) {
        self.messageSender = messageSender
        self.operationContext = operationContext
    }

    func send(_ message: TableMessage, conversation: MSConversation) -> TableMessageCommitResult {
        switch messageSender.send(message, in: conversation) {
        case .sent:
            return .sent
        case .encodingFailed(let error):
            return .encodingFailed(error)
        }
    }

    func applyAndSend(_ kind: TableOperation.Kind, to message: TableMessage,
                      actorID: String, conversation: MSConversation) -> TableMessageCommitResult {
        let result: TableOperationResult
        do {
            result = try message.committing(kind,
                                            actorID: actorID,
                                            operationID: operationContext.makeID(),
                                            knownBy: messageSender.revisionTracker(),
                                            now: operationContext.now())
        } catch {
            return .encodingFailed(error)
        }

        switch result {
        case .applied(let next):
            return send(next, conversation: conversation)
        case .unchanged:
            return .unchanged
        case .rejected(.stale):
            return .stale(message)
        case .rejected(let reason):
            return .rejected(message, reason)
        }
    }
}
