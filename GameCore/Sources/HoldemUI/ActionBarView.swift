import SwiftUI
import GameCore

/// The bottom action controls: Fold, Check/Call, Raise, and an expanded raise
/// sizing panel when more than one raise total is legal.
struct ActionBarView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let legal: LegalActions
    let bigBlind: Int
    let pot: Int
    let onAction: (PlayerAction) -> Void

    @State private var raising = false

    var body: some View {
        Group {
            if raising, let raiseBounds = legal.raiseBounds {
                RaisePanelView(
                    raiseBounds: raiseBounds,
                    currentBet: legal.currentBet,
                    callAmount: legal.callAmount,
                    bigBlind: bigBlind,
                    pot: pot,
                    onRaise: { onAction(.raise(to: $0)) },
                    onClose: { raising = false }
                )
            } else {
                primaryRow
            }
        }
        .onChange(of: legal) { raising = false }
    }

    private var primaryRow: some View {
        actionLayout {
            if legal.canFold {
                actionButton(title: "Fold",
                             accessibilityID: "table.action.fold",
                             destructive: true,
                             action: { onAction(.fold) })
            }
            if legal.canCheck {
                actionButton(title: "Check",
                             accessibilityID: "table.action.check",
                             action: { onAction(.check) })
            } else if legal.canCall {
                actionButton(title: "Call \(ChipText.string(legal.callAmount))",
                             accessibilityID: "table.action.call",
                             action: { onAction(.call) })
            }
            if let raiseBounds = legal.raiseBounds {
                if raiseBounds.lowerBound == raiseBounds.upperBound {
                    actionButton(
                        title: "All in \(ChipText.string(raiseBounds.lowerBound))",
                        accessibilityID: "table.action.allIn",
                        action: { onAction(.raise(to: raiseBounds.lowerBound)) }
                    )
                } else {
                    actionButton(title: "Raise",
                                 accessibilityID: "table.action.raise.expand",
                                 action: { raising = true })
                        .accessibilityHint("Opens raise amount controls")
                }
            }
        }
    }

    private var actionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func actionButton(title: String, accessibilityID: String,
                              destructive: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            Text(title)
                .font(.body.weight(destructive ? .semibold : .medium))
                .foregroundStyle(destructive ? Theme.dangerText : .white)
                .stableOneLineText(minScale: 0.78)
                .frame(minWidth: destructive ? 68 : nil,
                       maxWidth: destructive ? nil : .infinity)
                .frame(minHeight: Theme.Metrics.actionControlHeight)
                .controlSurface(fill: destructive ? Theme.dangerBackground : Theme.controlBackground,
                                stroke: destructive ? Theme.dangerStroke : Theme.controlStroke)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct RaisePanelView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let raiseBounds: ClosedRange<Int>
    let currentBet: Int
    let callAmount: Int
    let bigBlind: Int
    let pot: Int
    let onRaise: (Int) -> Void
    let onClose: () -> Void

    @State private var raiseTo = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Label("Raise to \(selectedRaiseText)", systemImage: "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .controlSurface()
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Close raise options")
                .accessibilityIdentifier("table.raise.close")
            }

            Slider(value: Binding(
                       get: { Double(selectedRaiseTo) },
                       set: { setRaise(Int($0)) }
                   ),
                   in: Double(raiseBounds.lowerBound)...Double(raiseBounds.upperBound),
                   step: 1)
                .tint(.white)
                .accessibilityLabel("Raise amount")
                .accessibilityValue(selectedRaiseText)
                .accessibilityIdentifier("table.raise.slider")

            VStack(spacing: 8) {
                presetLayout {
                    presetButton(title: "+1 BB",
                                 accessibilityID: "table.raise.preset.1bb") {
                        setRaise(selectedRaiseTo + bigBlind)
                    }
                    presetButton(title: "1/2 Pot",
                                 accessibilityID: "table.raise.preset.halfPot") {
                        setRaise(recommendedRaiseTo(potDivisor: 2))
                    }
                    presetButton(title: "Pot",
                                 accessibilityID: "table.raise.preset.pot") {
                        setRaise(recommendedRaiseTo(potDivisor: 1))
                    }
                    presetButton(title: "All in",
                                 accessibilityID: "table.raise.preset.allIn") {
                        setRaise(raiseBounds.upperBound)
                    }
                }
                PrimaryActionButton(
                    title: "Raise",
                    minHeight: Theme.Metrics.compactControlHeight,
                    accessibilityID: "table.raise.submit",
                    accessibilityLabel: "Raise to \(selectedRaiseText)"
                ) {
                    onRaise(selectedRaiseTo)
                    onClose()
                }
            }
        }
        .onChange(of: raiseBounds) { setRaise(selectedRaiseTo) }
    }

    private var presetLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    private func presetButton(title: String, accessibilityID: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .stableOneLineText(minScale: 0.78)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.Metrics.compactControlHeight)
                .controlSurface()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(accessibilityID)
    }

    private func setRaise(_ value: Int) {
        raiseTo = min(max(value, raiseBounds.lowerBound), raiseBounds.upperBound)
    }

    private func recommendedRaiseTo(potDivisor: Int) -> Int {
        let requestedIncrease = (pot + callAmount) / potDivisor
        let safeIncrease = min(requestedIncrease, raiseBounds.upperBound - currentBet)
        return max(currentBet + safeIncrease, raiseBounds.lowerBound)
    }

    private var selectedRaiseTo: Int {
        min(max(raiseTo, raiseBounds.lowerBound), raiseBounds.upperBound)
    }

    private var selectedRaiseText: String {
        ChipText.string(selectedRaiseTo)
    }
}
