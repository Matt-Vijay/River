import SwiftUI

struct ActionPrimaryButton: View {
    let title: String
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .stableOneLineText(minScale: 0.78)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Metrics.actionControlHeight)
                .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(Theme.controlBackground))
        }
        .buttonStyle(PressableButtonStyle())
        .optionalAccessibilityIdentifier(accessibilityID)
    }
}

struct ActionDestructiveButton: View {
    let title: String
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.dangerText)
                .stableOneLineText(minScale: 0.78)
                .frame(minWidth: 68)
                .frame(height: Theme.Metrics.actionControlHeight)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                        .fill(Theme.dangerBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                                .stroke(Theme.dangerStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PressableButtonStyle())
        .optionalAccessibilityIdentifier(accessibilityID)
    }
}

struct ActionIconButton: View {
    let systemName: String
    var accessibilityLabel: String? = nil
    var accessibilityID: String? = nil
    var foreground: Color = .white
    var background: Color = Theme.controlBackground
    var width: CGFloat = Theme.Metrics.actionControlHeight
    var height: CGFloat = Theme.Metrics.actionControlHeight
    var cornerRadius: CGFloat = Theme.Metrics.controlCorner
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: width, height: height)
                .background(RoundedRectangle(cornerRadius: cornerRadius).fill(background))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel ?? systemName)
        .optionalAccessibilityIdentifier(accessibilityID)
    }
}

struct RaisePresetButton: View {
    let title: String
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .stableOneLineText(minScale: 0.78)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Metrics.compactControlHeight)
                .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(Theme.controlBackground))
        }
        .buttonStyle(PressableButtonStyle())
        .optionalAccessibilityIdentifier(accessibilityID)
    }
}
