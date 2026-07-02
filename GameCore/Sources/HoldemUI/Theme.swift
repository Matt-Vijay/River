import SwiftUI
import GameCore

/// Visual constants tuned to match the reference screenshots: pure-black table,
/// white rounded cards, amber bet chips, green accents.
enum Theme {
    static let background = Color.black
    static let cardFace = Color(white: 0.97)
    static let cardBackTint = Color(white: 0.92)
    static let hatch = Color(white: 0.45)
    static let red = Color(red: 0.95, green: 0.26, blue: 0.21)
    static let ink = Color(white: 0.07)
    static let chip = Color(red: 0.98, green: 0.78, blue: 0.18)     // amber bet text
    static let chipBackground = Color(white: 0.12)
    static let accent = Color(red: 0.22, green: 0.85, blue: 0.5)    // green timer / win
    static let warn = Color(red: 0.96, green: 0.6, blue: 0.2)       // timer running low
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
        static let cardCorner: CGFloat = 12
        static let boardCardWidth: CGFloat = 62
        static let boardCardHeight: CGFloat = 88
        static let holeCardWidth: CGFloat = 82
        static let holeCardHeight: CGFloat = 116
    }
}

extension Suit {
    var color: Color { isRed ? Theme.red : Theme.ink }
}

extension Animation {
    /// The one transition curve used everywhere — an explicit cubic Bézier
    /// (standard ease, never linear) for smooth, continuous motion.
    static let tableSnap = Animation.timingCurve(0.33, 0.0, 0.2, 1.0, duration: 0.4)
    /// Faster cubic Bézier for press feedback (still a bezier, never linear/spring).
    static let tablePress = Animation.timingCurve(0.33, 0.0, 0.2, 1.0, duration: 0.16)
}

/// Press feedback for custom-styled buttons (HIG: controls need a press state).
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.tablePress, value: configuration.isPressed)
    }
}
