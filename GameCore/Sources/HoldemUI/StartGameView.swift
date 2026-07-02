import SwiftUI

/// Shown when there's no game in the conversation yet.
public struct StartGameView: View {
    public var profileName: String
    public var profileAvatar: String
    public var onStart: () -> Void
    public var onEditProfile: () -> Void

    public init(profileName: String,
                profileAvatar: String,
                onStart: @escaping () -> Void,
                onEditProfile: @escaping () -> Void) {
        self.profileName = profileName
        self.profileAvatar = profileAvatar
        self.onStart = onStart
        self.onEditProfile = onEditProfile
    }

    public var body: some View {
        ConversationPrompt(icon: .system("suit.spade.fill"),
                           title: "River",
                           message: "Open a table for this chat. Everyone joins with their saved profile and readies up.",
                           spacing: 18) {
            VStack(spacing: 14) {
                ProfileSummaryRow(name: profileName,
                                  avatar: profileAvatar,
                                  summaryAccessibilityID: HoldemAccessibility.Conversation.profileSummary,
                                  editAccessibilityID: HoldemAccessibility.Conversation.editProfile,
                                  onEditProfile: onEditProfile)
                ConversationActionButton(title: "Start a table",
                                         accessibilityID: HoldemAccessibility.Conversation.startTable,
                                         action: onStart)
            }
        }
    }
}
