import SwiftUI
import GameCore

struct RaisePanelView: View {
    let legal: LegalActions
    let bigBlind: Int
    let pot: Int
    @Binding var raiseTo: Double
    let onRaise: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Label("Raise to \(selectedRaiseText)", systemImage: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                ActionIconButton(systemName: "xmark",
                                 accessibilityLabel: "Close raise options",
                                 accessibilityID: HoldemAccessibility.Table.closeRaise,
                                 width: 44,
                                 height: 36,
                                 cornerRadius: 10,
                                 action: onClose)
            }

            Slider(value: $raiseTo,
                   in: Double(legal.minRaiseTo)...Double(max(legal.minRaiseTo, legal.maxRaiseTo)))
                .tint(.white)
                .accessibilityLabel("Raise amount")
                .accessibilityValue(selectedRaiseText)
                .accessibilityIdentifier(HoldemAccessibility.Table.raiseSlider)

            HStack(spacing: 8) {
                RaisePresetButton(title: "+1 BB",
                                  accessibilityID: HoldemAccessibility.Table.raisePreset("1bb")) {
                    setRaise(Int(raiseTo) + bigBlind)
                }
                RaisePresetButton(title: "1/2 Pot",
                                  accessibilityID: HoldemAccessibility.Table.raisePreset("halfPot")) {
                    setRaise(legal.recommendedRaiseTo(.halfPot, pot: pot))
                }
                RaisePresetButton(title: "Pot",
                                  accessibilityID: HoldemAccessibility.Table.raisePreset("pot")) {
                    setRaise(legal.recommendedRaiseTo(.pot, pot: pot))
                }
                Button {
                    onRaise(selectedRaiseTo)
                    onClose()
                } label: {
                    Text("Raise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .stableOneLineText(minScale: 0.78)
                        .frame(minWidth: 70)
                        .frame(height: Theme.Metrics.compactControlHeight)
                        .background(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(.white))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Raise to \(selectedRaiseText)")
                .accessibilityIdentifier(HoldemAccessibility.Table.submitRaise)
            }
        }
    }

    private func setRaise(_ value: Int) {
        withAnimation(.tableSnap) {
            raiseTo = Double(min(max(value, legal.minRaiseTo), legal.maxRaiseTo))
        }
    }

    private var selectedRaiseTo: Int {
        min(max(Int(raiseTo), legal.minRaiseTo), legal.maxRaiseTo)
    }

    private var selectedRaiseText: String {
        ChipFormatter.string(selectedRaiseTo)
    }
}
