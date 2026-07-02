import SwiftUI

/// Shown in the compact presentation as the tap target that opens the table.
public struct CompactSummaryView: View {
    public let summary: String
    public var onOpen: () -> Void

    public init(summary: String, onOpen: @escaping () -> Void) {
        self.summary = summary
        self.onOpen = onOpen
    }

    public var body: some View {
        Button(action: onOpen) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "suit.spade.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("River")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 12)

                Text(summary)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)

                Image(systemName: "arrow.up.forward.app")
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 18, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                    .fill(Theme.controlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                            .stroke(Theme.controlStroke, lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .accessibilityLabel("Open table. \(summary)")
        .accessibilityIdentifier(HoldemAccessibility.Conversation.openTable)
    }
}
