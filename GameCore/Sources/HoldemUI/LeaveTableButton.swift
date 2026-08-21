import SwiftUI

struct LeaveTableButton: View {
    enum Style { case icon, text }

    let consequence: String
    var style = Style.icon
    var accessibilityID = HoldemAccessibility.Table.leave
    var confirmAccessibilityID = HoldemAccessibility.Table.confirmLeave
    var cancelAccessibilityID = HoldemAccessibility.Table.cancelLeave
    let action: () -> Void

    @State private var isConfirmingLeave = false

    var body: some View {
        Button {
            isConfirmingLeave = true
        } label: {
            label
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Leave table")
        .accessibilityIdentifier(accessibilityID)
        .alert(
            "Leave this table?",
            isPresented: $isConfirmingLeave
        ) {
            Button("Stay", role: .cancel) {}
                .accessibilityIdentifier(cancelAccessibilityID)
            Button("Leave table", role: .destructive, action: action)
                .accessibilityIdentifier(confirmAccessibilityID)
        } message: {
            Text(consequence)
        }
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .icon:
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 44, height: 44)
        case .text:
            Text("Leave table")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .stableOneLineText()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
    }
}
