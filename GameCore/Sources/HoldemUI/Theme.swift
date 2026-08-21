import SwiftUI
import GameCore

enum Theme {
    static let background = Color.black
    static let cardFace = Color(white: 0.97)
    static let cardBackTint = Color(white: 0.92)
    static let hatch = Color(white: 0.45)
    static let red = Color(red: 0.95, green: 0.26, blue: 0.21)
    static let ink = Color(white: 0.07)
    static let chip = Color(red: 0.98, green: 0.78, blue: 0.18)
    static let accent = Color(red: 0.22, green: 0.85, blue: 0.5)
    static let warn = Color(red: 0.96, green: 0.6, blue: 0.2)
    static let secondaryText = Color(white: 0.55)
    static let controlBackground = Color(white: 0.12)
    static let controlStroke = Color(white: 0.22)
    static let dangerText = Color(red: 1.0, green: 0.45, blue: 0.40)
    static let dangerBackground = Color(red: 0.22, green: 0.07, blue: 0.06)
    static let dangerStroke = Color(red: 0.55, green: 0.18, blue: 0.15)

    enum Metrics {
        static let controlCorner: CGFloat = 8
        static let actionControlHeight: CGFloat = 56
        static let compactControlHeight: CGFloat = 44
        static let boardCardWidth: CGFloat = 62
        static let boardCardHeight: CGFloat = 88
        static let holeCardWidth: CGFloat = 82
        static let holeCardHeight: CGFloat = 116
    }
}

extension Suit {
    var color: Color { isRed ? Theme.red : Theme.ink }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

extension View {
    func controlSurface(stroke: Color = Theme.controlStroke) -> some View {
        background(
            RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                .fill(Theme.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                        .stroke(stroke, lineWidth: 1)
                )
        )
    }
}

struct PrimaryActionButton: View {
    let title: String
    var systemImage: String? = nil
    var minHeight = Theme.Metrics.actionControlHeight
    var isDisabled = false
    let accessibilityID: String
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(isDisabled ? Theme.secondaryText : .black)
            .stableOneLineText()
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                .fill(isDisabled ? Theme.controlBackground : .white))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityIdentifier(accessibilityID)
    }
}

extension View {
    func stableOneLineText(
        minScale: CGFloat = 0.82,
        accessibilityLineLimit: Int? = 2,
        alignment: TextAlignment = .center
    ) -> some View {
        modifier(StableTextModifier(
            minScale: minScale,
            accessibilityLineLimit: accessibilityLineLimit,
            alignment: alignment
        ))
    }
}

private struct StableTextModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let minScale: CGFloat
    let accessibilityLineLimit: Int?
    let alignment: TextAlignment

    func body(content: Content) -> some View {
        let usesAccessibleLayout = dynamicTypeSize.isAccessibilitySize
        content
            .lineLimit(usesAccessibleLayout ? accessibilityLineLimit : 1)
            .minimumScaleFactor(usesAccessibleLayout ? 1 : minScale)
            .multilineTextAlignment(alignment)
    }
}
