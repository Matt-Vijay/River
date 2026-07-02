import SwiftUI

/// Shown when you open a game in progress that you're not seated in yet.
public struct JoinGameView: View {
    public let summary: String
    public var profileName: String
    public var profileAvatar: String
    public var onJoin: () -> Void
    public var onEditProfile: () -> Void

    public init(summary: String,
                profileName: String,
                profileAvatar: String,
                onJoin: @escaping () -> Void,
                onEditProfile: @escaping () -> Void) {
        self.summary = summary
        self.profileName = profileName
        self.profileAvatar = profileAvatar
        self.onJoin = onJoin
        self.onEditProfile = onEditProfile
    }

    public var body: some View {
        ConversationPrompt(icon: .system("suit.spade.fill"),
                           title: "Game in progress",
                           message: summary) {
            VStack(spacing: 14) {
                ProfileSummaryRow(name: profileName,
                                  avatar: profileAvatar,
                                  summaryAccessibilityID: HoldemAccessibility.Conversation.profileSummary,
                                  editAccessibilityID: HoldemAccessibility.Conversation.editProfile,
                                  onEditProfile: onEditProfile)
                ConversationActionButton(title: "Join next hand",
                                         accessibilityID: HoldemAccessibility.Conversation.joinGame,
                                         action: onJoin)
            }
        }
    }
}
