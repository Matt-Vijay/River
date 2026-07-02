import SwiftUI
import GameCore
#if canImport(UIKit)
import UIKit
#endif

/// First-run screen to pick a handle and avatar.
public struct ProfileSetupView: View {
    @State private var name: String
    @State private var avatar: String
    @FocusState private var isHandleFocused: Bool
    private let onSave: (String, String) -> Void
    private let onCancel: (() -> Void)?

    public init(name: String = "",
                avatar: String = "🙂",
                onSave: @escaping (String, String) -> Void,
                onCancel: (() -> Void)? = nil) {
        _name = State(initialValue: name)
        _avatar = State(initialValue: avatar)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var hasName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var handle: Binding<String> {
        Binding(
            get: { name },
            set: { name = String($0.prefix(ProfileText.maxNameLength)) }
        )
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                avatarPreview
                avatarPicker
                handleField
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, onCancel == nil ? 96 : 132)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            actions
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .background(Theme.background)
        }
    }

    private var header: some View {
        Text("Set up your seat")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var avatarPreview: some View {
        Text(avatar)
            .font(.system(size: 56))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Selected character \(avatar)")
    }

    private var avatarPicker: some View {
        CharacterPicker(
            selectedAvatar: avatar,
            buttonSize: 44,
            emojiSize: 32,
            gridSpacing: 12
        ) { avatar = $0 }
    }

    private var handleField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Handle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            TextField("", text: handle, prompt: Text("Maverick").foregroundStyle(Theme.secondaryText))
                .textFieldStyle(.plain)
                .textContentType(.nickname)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isHandleFocused)
                .onChange(of: name) { _, newValue in
                    let capped = String(newValue.prefix(ProfileText.maxNameLength))
                    if capped != newValue {
                        Task { @MainActor in
                            name = capped
                        }
                    }
                }
                .onSubmit {
                    if hasName { saveProfile() }
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                        .fill(Theme.controlBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                                .stroke(Theme.controlStroke, lineWidth: 1)
                        )
                )
                .accessibilityIdentifier(HoldemAccessibility.Profile.nameField)
                .modifier(BoundedProfileNameInput(text: $name))
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: saveProfile) {
                Text("Save profile")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .stableOneLineText()
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(hasName ? .white : Theme.secondaryText))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!hasName)
            .accessibilityIdentifier(HoldemAccessibility.Profile.save)

            if let onCancel {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .stableOneLineText()
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(HoldemAccessibility.Profile.cancel)
            }
        }
    }

    private func saveProfile() {
        isHandleFocused = false
        onSave(ProfileText.name(name), ProfileText.avatar(avatar))
    }
}

private struct BoundedProfileNameInput: ViewModifier {
    @Binding var text: String

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content.onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)) { notification in
            guard let field = notification.object as? UITextField else { return }
            let value = field.text ?? ""
            let capped = String(value.prefix(ProfileText.maxNameLength))
            if value != capped {
                field.text = capped
            }
            if text != capped {
                text = capped
            }
        }
        #else
        content
        #endif
    }
}

#Preview("Profile") {
    ProfileSetupView(onSave: { _, _ in })
}
