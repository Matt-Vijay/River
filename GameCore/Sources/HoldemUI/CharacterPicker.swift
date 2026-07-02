import SwiftUI

struct CharacterPicker: View {
    let selectedAvatar: String?
    var buttonSize: CGFloat = 40
    var emojiSize: CGFloat = 28
    var gridSpacing: CGFloat = 10
    let onPick: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(Array(CharacterAvatars.all.enumerated()), id: \.element) { index, emoji in
                    CharacterAvatarButton(
                        emoji: emoji,
                        accessibilityID: HoldemAccessibility.Profile.avatar(index),
                        isSelected: emoji == selectedAvatar,
                        buttonSize: buttonSize,
                        emojiSize: emojiSize,
                        onPick: onPick
                    )
                }
            }
        }
    }
}

private struct CharacterAvatarButton: View {
    let emoji: String
    let accessibilityID: String
    let isSelected: Bool
    let buttonSize: CGFloat
    let emojiSize: CGFloat
    let onPick: (String) -> Void

    var body: some View {
        Button {
            onPick(emoji)
        } label: {
            Text(emoji)
                .font(.system(size: emojiSize))
                .frame(width: buttonSize, height: buttonSize)
                .background(Circle().fill(isSelected ? Theme.accent.opacity(0.25) : .clear))
                .overlay(Circle().strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Selected character \(emoji)" : "Choose character \(emoji)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityID)
    }
}
