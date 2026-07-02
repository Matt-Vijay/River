import Messages
import GameCore

enum SelectedTableMessage {
    case none
    case invalidPayload
    case message(TableMessage)
}

enum MessagePayloads {
    static func selectedTableMessage(in conversation: MSConversation) -> SelectedTableMessage {
        guard let url = conversation.selectedMessage?.url else { return .none }

        do {
            return .message(try GamePayload.decodeMessage(from: url))
        } catch {
            return .invalidPayload
        }
    }

    static func makeMessage(for message: TableMessage, in conversation: MSConversation) throws -> MSMessage {
        let messageView = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        let summary = GamePayload.summary(for: message)
        let layout = MSMessageTemplateLayout()

        layout.caption = "River"
        layout.subcaption = summary
        messageView.layout = layout
        messageView.summaryText = "River: \(summary)"
        messageView.url = try GamePayload.encodeToURL(message)

        return messageView
    }
}
