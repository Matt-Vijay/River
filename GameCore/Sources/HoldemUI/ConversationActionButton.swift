import SwiftUI

struct ConversationActionButton: View {
    let title: String
    var usesPressFeedback = true
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        if usesPressFeedback {
            Button(action: action, label: label)
                .buttonStyle(PressableButtonStyle())
                .optionalAccessibilityIdentifier(accessibilityID)
        } else {
            Button(action: action, label: label)
                .buttonStyle(.plain)
                .optionalAccessibilityIdentifier(accessibilityID)
        }
    }

    private func label() -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.black)
            .stableOneLineText()
            .padding(.horizontal, 28)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(.white))
    }
}
