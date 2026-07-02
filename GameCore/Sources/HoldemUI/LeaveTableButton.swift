import SwiftUI

struct LeaveTableButton: View {
    let action: () -> Void

    @State private var isConfirmingLeave = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.tableSnap) {
                    isConfirmingLeave = true
                }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isConfirmingLeave ? Theme.dangerText : Theme.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                            .fill(Color.black.opacity(0.72))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                                    .stroke(isConfirmingLeave ? Theme.dangerStroke : Theme.controlStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Leave table")
            .accessibilityValue(isConfirmingLeave ? "Confirmation open" : "Confirmation closed")
            .accessibilityIdentifier(HoldemAccessibility.Table.leave)

            if isConfirmingLeave {
                HStack(spacing: 8) {
                    Button("Stay", role: .cancel) {
                        withAnimation(.tableSnap) {
                            isConfirmingLeave = false
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .stableOneLineText()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(Theme.controlBackground))
                    .accessibilityIdentifier(HoldemAccessibility.Table.cancelLeave)

                    Button("Leave table", role: .destructive) {
                        isConfirmingLeave = false
                        action()
                    }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.dangerText)
                        .stableOneLineText()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(Theme.dangerBackground))
                        .accessibilityIdentifier(HoldemAccessibility.Table.confirmLeave)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                        .fill(Color.black.opacity(0.86))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).stroke(Theme.controlStroke, lineWidth: 1))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
