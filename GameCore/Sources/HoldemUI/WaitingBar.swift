import SwiftUI

/// Disabled pill shown when it isn't your turn or you're out of the hand.
struct WaitingBar: View {
    var text: String = "Wait for the next hand"

    var body: some View {
        Text(text)
            .font(.system(size: 17))
            .foregroundStyle(Theme.secondaryText)
            .stableOneLineText(minScale: 0.78)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Metrics.actionControlHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                    .strokeBorder(Theme.controlStroke, lineWidth: 1)
            )
            .accessibilityLabel(text)
            .accessibilityIdentifier(HoldemAccessibility.Table.waiting)
    }
}
