import SwiftUI

struct LobbyActions: View {
    let isJoined: Bool
    let isReady: Bool
    let isFull: Bool
    let profileName: String?
    let profileAvatar: String?
    let onJoin: () -> Void
    let onToggleReady: () -> Void
    let onLeave: (() -> Void)?
    let onEditProfile: (() -> Void)?
    let onAddTestPlayer: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            if isJoined {
                joinedActions
            } else {
                preJoinActions
            }

            if isJoined, let onAddTestPlayer, !isFull {
                addTestPlayerButton(action: onAddTestPlayer)
            }
        }
    }

    private var joinedActions: some View {
        VStack(spacing: 10) {
            readyButton
            if let onLeave {
                LobbyTextButton(title: "Leave table",
                                accessibilityID: HoldemAccessibility.Lobby.leave,
                                action: onLeave)
            }
        }
    }

    private var preJoinActions: some View {
        VStack(spacing: 12) {
            if let profileName, let profileAvatar, let onEditProfile {
                ProfileSummaryRow(name: profileName,
                                  avatar: profileAvatar,
                                  onEditProfile: onEditProfile)
            }
            joinButton
        }
    }

    private var readyButton: some View {
        LobbyPrimaryButton(
            title: isReady ? "Unready" : "Ready up",
            accessibilityID: HoldemAccessibility.Lobby.ready,
            foreground: isReady ? .black : .white,
            fill: isReady ? Theme.accent : Theme.controlBackground,
            action: onToggleReady
        )
    }

    private var joinButton: some View {
        LobbyPrimaryButton(
            title: isFull ? "Table full" : "Join table",
            accessibilityID: HoldemAccessibility.Lobby.join,
            foreground: .black,
            fill: isFull ? .gray : .white,
            isDisabled: isFull,
            action: onJoin
        )
    }

    private func addTestPlayerButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Add player", systemImage: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(HoldemAccessibility.Lobby.addTestPlayer)
    }
}

struct ProfileSummaryRow: View {
    let name: String
    let avatar: String
    var summaryAccessibilityID = HoldemAccessibility.Lobby.profileSummary
    var editAccessibilityID = HoldemAccessibility.Lobby.editProfile
    let onEditProfile: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProfileIdentitySummary(name: name,
                                   avatar: avatar,
                                   accessibilityID: summaryAccessibilityID)
                .layoutPriority(1)

            Spacer(minLength: 8)

            Button(action: onEditProfile) {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Edit profile")
                .accessibilityIdentifier(editAccessibilityID)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                .fill(Theme.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                        .stroke(Theme.controlStroke, lineWidth: 1)
                )
        )
    }
}

private struct ProfileIdentitySummary: View {
    let name: String
    let avatar: String
    let accessibilityID: String

    var body: some View {
        HStack(spacing: 12) {
            Text(avatar)
                .font(.system(size: 28))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Playing as")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playing as \(name)")
        .accessibilityIdentifier(accessibilityID)
    }
}
