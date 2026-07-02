import SwiftUI

struct LobbyPrimaryButton: View {
    let title: String
    var accessibilityID: String? = nil
    var foreground: Color = .white
    var fill: Color = Theme.controlBackground
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(foreground)
                .stableOneLineText()
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(fill))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isDisabled)
        .optionalAccessibilityIdentifier(accessibilityID)
    }
}

struct LobbyTextButton: View {
    let title: String
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
            .stableOneLineText()
            .buttonStyle(PressableButtonStyle())
            .optionalAccessibilityIdentifier(accessibilityID)
    }
}
