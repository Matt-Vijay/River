import SwiftUI
import GameCore

/// First-run screen to pick a handle and avatar.
public struct ProfileSetupView: View {
    @State private var name = ""
    @State private var avatar = "🙂"
    @FocusState private var isHandleFocused: Bool
    private let onSave: (PlayerProfile) -> Void

    public init(onSave: @escaping (PlayerProfile) -> Void) {
        self.onSave = onSave
    }

    private var profile: PlayerProfile? {
        PlayerProfile(name: name, avatar: avatar)
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Create profile")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    handleField
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(minimum: Metrics.buttonSize, maximum: Metrics.buttonSize),
                                spacing: Metrics.gridSpacing
                            )
                        ],
                        spacing: Metrics.gridSpacing
                    ) {
                        ForEach(CharacterAvatars.all.indices, id: \.self) { index in
                            let emoji = CharacterAvatars.all[index]
                            let isSelected = emoji == avatar
                            Button { avatar = emoji } label: {
                                Text(emoji)
                                    .font(.system(size: Metrics.emojiSize))
                                    .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
                                    .background(Circle().fill(isSelected ? Color.white.opacity(0.12) : .clear))
                                    .overlay(Circle().strokeBorder(isSelected ? .white : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isSelected ? "Selected character \(emoji)" : "Choose character \(emoji)")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                            .accessibilityIdentifier(HoldemAccessibility.Profile.avatar(index))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryActionButton(
                title: "Save profile",
                isDisabled: profile == nil,
                accessibilityID: HoldemAccessibility.Profile.save,
                action: saveProfile
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .background(Theme.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private var handleField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Handle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityHidden(true)

            TextField("", text: $name, prompt: Text("Maverick").foregroundStyle(Theme.secondaryText))
                .textFieldStyle(.plain)
                .textContentType(.nickname)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isHandleFocused)
                .onSubmit {
                    if profile != nil { saveProfile() }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .accessibilityLabel("Handle")
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .controlSurface()
                .accessibilityIdentifier(HoldemAccessibility.Profile.nameField)
                .onChange(of: name) {
                    let bounded = ProfileText.boundedEditingName(name)
                    if bounded != name {
                        name = bounded
                    }
                }
        }
    }

    private func saveProfile() {
        guard let profile else { return }
        isHandleFocused = false
        onSave(profile)
    }

    private enum Metrics {
        static let buttonSize: CGFloat = 44
        static let emojiSize: CGFloat = 32
        static let gridSpacing: CGFloat = 12
    }
}
enum CharacterAvatars {
    static let all = ["🙂", "🧑🏻", "🧑🏼", "🧑🏽", "🧑🏾", "🧑🏿", "👩🏻", "👨🏿", "🐱", "🐶", "🦊", "🐼", "👽"]
}
