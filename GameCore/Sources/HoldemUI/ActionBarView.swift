import SwiftUI
import GameCore

/// The bottom action controls: Fold, Check/Call, Raise, and an expanded raise
/// sizing panel. The hole-card swipe remains as a shortcut, not the only fold
/// affordance.
struct ActionBarView: View {
    let legal: LegalActions
    let bigBlind: Int
    let pot: Int
    let onFold: () -> Void
    let onCheck: () -> Void
    let onCall: () -> Void
    let onRaise: (Int) -> Void

    @State private var raising = false
    @State private var raiseTo: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            if raising {
                raisePanel.transition(.opacity)
            } else {
                primaryRow.transition(.opacity)
            }
        }
        .animation(.tableSnap, value: raising)
    }

    private var primaryRow: some View {
        HStack(spacing: 12) {
            if legal.canFold {
                ActionDestructiveButton(title: "Fold",
                                        accessibilityID: HoldemAccessibility.Table.fold,
                                        action: onFold)
            }
            if legal.canCheck {
                ActionPrimaryButton(title: "Check",
                                    accessibilityID: HoldemAccessibility.Table.check,
                                    action: onCheck)
            } else if legal.canCall {
                ActionPrimaryButton(title: "Call \(ChipFormatter.string(legal.callAmount))",
                                    accessibilityID: HoldemAccessibility.Table.call,
                                    action: onCall)
            }
            if legal.canRaise {
                ActionPrimaryButton(title: "Raise",
                                    accessibilityID: HoldemAccessibility.Table.expandRaise,
                                    action: openRaisePanel)
            }
        }
    }

    private var raisePanel: some View {
        RaisePanelView(legal: legal,
                       bigBlind: bigBlind,
                       pot: pot,
                       raiseTo: $raiseTo,
                       onRaise: onRaise,
                       onClose: { raising = false })
    }

    private func setRaise(_ value: Int) {
        raiseTo = Double(min(max(value, legal.minRaiseTo), legal.maxRaiseTo))
    }

    private func openRaisePanel() {
        setRaise(legal.minRaiseTo)
        raising = true
    }
}
