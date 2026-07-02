import SwiftUI

/// Shown when a finished table is opened from Messages. No join action is
/// offered because the game has an overall winner.
public struct GameOverView: View {
    public let summary: String

    public init(summary: String) {
        self.summary = summary
    }

    public var body: some View {
        ConversationPrompt(icon: .system("trophy.fill"),
                           title: "Game over",
                           message: summary) {
            EmptyView()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game over. \(summary)")
        .accessibilityValue("No actions available")
        .accessibilityIdentifier(HoldemAccessibility.Conversation.gameOver)
    }
}
