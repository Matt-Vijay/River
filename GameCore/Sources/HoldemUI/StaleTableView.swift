import SwiftUI
import GameCore

public struct StaleTablePresentation: Equatable {
    public enum Context: Equatable {
        case olderMessage
        case rejectedAction(TableOperationRejection? = nil)
        case invalidPayload
        case encodingFailed
        case sendFailed
    }

    public let title: String
    public let message: String
    public let guidance: String

    public init(summary: String, context: Context = .olderMessage) {
        title = switch context {
        case .olderMessage:
            "Older table message"
        case .rejectedAction:
            "Action not sent"
        case .invalidPayload:
            "Could not open table"
        case .encodingFailed:
            "Could not send table"
        case .sendFailed:
            "Could not send action"
        }
        message = summary
        guidance = switch context {
        case .olderMessage:
            "Open the newest River bubble in this chat to keep playing."
        case .rejectedAction(let reason):
            Self.rejectionGuidance(reason)
        case .invalidPayload:
            "This River bubble contains an invalid table payload. Open the newest bubble in this chat to keep playing."
        case .encodingFailed:
            "The table state is too large or invalid. Open the newest River bubble and try again."
        case .sendFailed:
            "Messages could not send that update. Open the newest River bubble and try again."
        }
    }

    private static func rejectionGuidance(_ reason: TableOperationRejection?) -> String {
        switch reason {
        case .duplicateOperation:
            "That action was already applied. Open the newest River bubble to keep playing."
        case .invalidOperationIdentity:
            "That action link is invalid. Open the newest River bubble and try again."
        case .stale:
            "Open the newest River bubble in this chat, then try again."
        case .wrongTable:
            "That action belongs to another table. Open the matching River bubble to keep playing."
        case .wrongPhase:
            "That action does not match the current table state. Open the newest River bubble and try again."
        case .notSeated:
            "Join this table before taking that action."
        case .notActorTurn:
            "It is not your turn."
        case .illegalAction:
            "That move is not legal right now."
        case .tableFull:
            "This table is full."
        case .gameOver:
            "This game is already over."
        case nil:
            "Open the newest River bubble in this chat, then try again."
        }
    }
}

/// Shown when this device has already seen a newer message for the same table.
public struct StaleTableView: View {
    public let presentation: StaleTablePresentation

    public init(summary: String, context: StaleTablePresentation.Context = .olderMessage) {
        self.presentation = StaleTablePresentation(summary: summary, context: context)
    }

    public var body: some View {
        ConversationPrompt(icon: .system("clock.arrow.circlepath"),
                           title: presentation.title,
                           message: presentation.message,
                           spacing: 18) {
            Text(presentation.guidance)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(HoldemAccessibility.Conversation.recovery)
    }
}
