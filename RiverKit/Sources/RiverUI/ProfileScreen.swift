import SwiftUI
import Poker

struct ProfileScreen: View {
    let onSave: (Profile) -> Void
    @Binding var name: String
    @Binding var avatar: String
    @FocusState private var editing: Bool

    private var profile: Profile? { Profile(name: name, avatar: avatar) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TextField("Your name", text: $name)
                    .font(.title3).textContentType(.nickname)
                    .autocorrectionDisabled().submitLabel(.done).focused($editing)
                    .padding(16).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("profile.name")
                    .onChange(of: editing) {
                        // Leave marked text intact until keyboard composition has ended.
                        if !editing { name = Profile.boundedName(name) }
                    }
                    .onSubmit(save)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 56), spacing: 12)], spacing: 16) {
                    ForEach(0..<Characters.all.count, id: \.self) { index in
                        let character = Characters.all[index]
                        Button { avatar = character } label: {
                            Avatar(text: character, size: 48)
                                .background(.primary.opacity(avatar == character ? 0.08 : 0), in: Circle())
                                .overlay(Circle().strokeBorder(avatar == character ? Color.primary : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Character \(character)")
                        .accessibilityAddTraits(avatar == character ? .isSelected : [])
                        .accessibilityIdentifier("profile.avatar.\(index)")
                    }
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .clipped()
        .safeAreaInset(edge: .top, spacing: 0) {
            Brand().frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 24)
                .avoidingWindowControls()
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.selection, trigger: avatar)
        .safeAreaInset(edge: .bottom) {
            ActionButton(title: "Continue", id: "profile.save", isEnabled: profile != nil, action: save)
                .padding(24).background(Color.black)
        }
        .frame(maxWidth: 560)
    }

    private func save() {
        guard let profile else { return }
        editing = false
        onSave(profile)
    }
}
