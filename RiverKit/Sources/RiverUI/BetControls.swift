import SwiftUI
import Poker

struct TableControls: View {
    let session: RiverSession
    let table: Poker.Table
    let now: Date
    @Binding var raising: RaiseSelection?
    var reveal: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .headline) private var titleHeight: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var amountHeight: CGFloat = 18
    @ScaledMetric(relativeTo: .subheadline) private var statusHeight: CGFloat = 40
    private var betContentHeight: CGFloat { titleHeight + amountHeight + 2 }
    private var wideAmounts: Bool { table.rules.buyIn * table.rules.capacity >= 1_000_000 }
    private var actionHeight: CGFloat {
        (betContentHeight + 24) * (textSize.isAccessibilitySize ? 3 : 1)
            + (textSize.isAccessibilitySize ? 20 : 0)
    }
    private var controlsHeight: CGFloat {
        let normalHeight = statusHeight + 12 + actionHeight
        // Reserve the same space in both modes, including all six accessibility rows.
        let rowHeight = max(52, titleHeight + 24)
        let composerHeight = textSize.isAccessibilitySize ? rowHeight * 6 + 50
            : wideAmounts ? rowHeight * 3 + 22 : rowHeight * 2 + 12
        return max(normalHeight, composerHeight)
    }

    private var legal: LegalBet? { table.legalBet(for: session.viewerID, at: now) }
    private var needsReentry: Bool {
        guard !session.isLocal, !table.isFinished else { return false }
        let seat = table.seat(session.viewerID)
        return seat?.hasLeft != false || (seat?.chips == 0 && table.hand?.isComplete == true)
    }
    private var statusTitle: String {
        if reveal != nil {
            return table.hand?.remaining(at: now) == 0 ? "Turn expired" : table.summary
        }
        if needsReentry {
            guard table.canJoin(session.viewerID) else { return "Table full" }
            return table.seat(session.viewerID)?.chips == 0
                ? "Out of chips. Reopen to rejoin." : "Reopen the table to join."
        }
        guard table.hand?.isComplete == true else {
            if table.hand?.remaining(at: now) == 0 { return "Turn expired" }
            return legal == nil ? table.summary : " "
        }
        let winners = table.awards.filter { $0.won > 0 }
        guard winners.count == 1, let winner = winners.first, let seat = table.seat(winner.id) else { return table.summary }
        return "\(seat.profile.name) won"
    }

    var body: some View {
        Group {
            if let selection = raising, legal != nil, reveal == nil {
                RaiseComposer(bounds: selection.bounds, call: selection.call, bet: table.currentBet,
                              pot: table.hand?.pot ?? 0, wideAmounts: wideAmounts,
                              amount: Binding(get: { raising?.amount ?? selection.amount }, set: {
                    if raising?.id == selection.id { raising?.amount = $0 }
                }), submit: {
                    guard raising?.id == selection.id else { return }
                    session.act(.bet(.raiseTo($0)), on: table)
                    raising = nil
                }, cancel: { raising = nil })
                .id(selection.id)
            } else {
                VStack(spacing: 12) {
                    Text(statusTitle)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(textSize.isAccessibilitySize ? 2 : 1, reservesSpace: true).truncationMode(.middle)
                        .frame(maxWidth: .infinity, minHeight: statusHeight)
                        .accessibilityLabel(reveal != nil ? "\(statusTitle). Hand hidden." : table.hand?.isComplete == true && !needsReentry ? table.summary : statusTitle)
                        .accessibilityHidden(legal != nil && reveal == nil)
                        .accessibilityIdentifier(reveal != nil ? "table.handoff" : table.hand?.isComplete == true ? "table.result" : "table.waiting")
                    actions
                        .lineLimit(2).truncationMode(.middle)
                        .frame(height: actionHeight, alignment: .top)
                }
            }
        }
        .frame(minHeight: controlsHeight)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.primary)
        .onChange(of: legal) { raising = nil }
    }

    private var actions: some View {
        Group {
            if needsReentry {
                ActionButton(title: "Close table", id: "table.close", prominent: false) { session.perform(.close) }
            } else if table.hand?.isComplete == true {
                if table.isFinished {
                    ActionButton(title: "New table", id: "table.new") { session.perform(.newTable) }
                } else {
                    ActionButton(title: "Deal next hand", id: "table.deal", isEnabled: table.canDeal) { deal() }
                }
            } else if table.hand?.remaining(at: now) == 0 {
                ActionButton(title: reveal != nil ? (table.stake(session.viewerID)?.bet == table.currentBet ? "Check" : "Fold hand") : table.timeoutTitle,
                             id: "table.timeout.resolve", prominent: false) {
                    session.act(.timeout, on: table)
                }
            } else if let reveal {
                Button("View hand", systemImage: "eye", action: reveal)
                    .buttonStyle(RiverButtonStyle(prominent: true))
                    .accessibilityIdentifier("table.handoff.reveal")
            } else if let legal {
                let layout = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                layout { bets(legal) }
            } else {
                Color.clear.accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private func bets(_ legal: LegalBet) -> some View {
        betButton("Fold", id: "table.fold") { session.act(.bet(.fold), on: table) }
        betButton(legal.canCheck ? "Check" : "Call", amount: legal.canCheck ? nil : legal.call, id: "table.call", prominent: true) {
            session.act(.bet(legal.canCheck ? .check : .call), on: table)
        }
        betButton(table.currentBet == 0 ? "Bet" : "Raise", id: "table.raise") {
            if let bounds = legal.raise {
                raising = RaiseSelection(bounds: bounds, call: legal.call)
            }
        }
        .disabled(legal.raise == nil)
        .opacity(legal.raise == nil ? 0 : 1)
        .allowsHitTesting(legal.raise != nil)
        .accessibilityHidden(legal.raise == nil)
    }

    private func betButton(_ title: String, amount: Int? = nil, id: String, prominent: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).lineLimit(1).minimumScaleFactor(0.8).frame(height: titleHeight)
                if let amount {
                    Text(Chips.text(amount)).font(.subheadline.monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(height: amountHeight)
                }
            }
            .frame(height: betContentHeight)
        }
        .buttonStyle(RiverButtonStyle(prominent: prominent))
        .accessibilityLabel(amount.map { "\(title) \(Chips.text($0)) chips" } ?? title)
        .accessibilityIdentifier(id)
    }

    private func deal() { session.act(.deal(seed: UInt64.random(in: .min ... .max)), on: table) }
}

extension Poker.Table {
    var timeoutTitle: String {
        guard let turn = hand?.turn, let player = seat(turn), let stake = stake(turn) else { return "Resolve turn" }
        return stake.bet == currentBet ? "Check for \(player.profile.name)" : "Fold \(player.profile.name)'s hand"
    }
}

struct RaiseSelection: Identifiable {
    let id = UUID()
    let bounds: ClosedRange<Int>
    let call: Int
    // Keep the amount when the table switches between portrait and landscape layouts.
    var amount: Int

    init(bounds: ClosedRange<Int>, call: Int) {
        self.bounds = bounds
        self.call = call
        amount = bounds.lowerBound
    }
}

private struct RaiseComposer: View {
    let bounds: ClosedRange<Int>
    let call: Int
    let bet: Int
    let pot: Int
    let wideAmounts: Bool
    @Binding var amount: Int
    let submit: (Int) -> Void
    let cancel: () -> Void
    @State private var presetFeedback = false
    @ScaledMetric(relativeTo: .headline) private var amountWidth: CGFloat = 72
    @Environment(\.dynamicTypeSize) private var textSize
    private var actionTitle: String { bet == 0 ? "Bet" : "Raise to" }
    private var amountDescription: String { "\(actionTitle) \(Chips.text(amount)) chips" }
    private var stacksAmount: Bool { textSize.isAccessibilitySize || wideAmounts }

    var body: some View {
        Group {
            if textSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    presets
                    amountControl
                    cancelButton
                }
            } else {
                VStack(spacing: 12) {
                    amountControl
                    HStack(spacing: 8) {
                        presets
                        cancelButton
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: presetFeedback)
    }

    private var amountControl: some View {
        let layout = stacksAmount
            ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
                Text("\(actionTitle)\(stacksAmount ? " " : "\n")\(Chips.text(amount))")
                    .font(.headline).monospacedDigit().multilineTextAlignment(.center)
                    .lineLimit(stacksAmount ? 1 : 2).minimumScaleFactor(0.5)
                    .frame(width: stacksAmount ? nil : amountWidth)
                    .frame(minHeight: 52)
                    .accessibilityLabel(amountDescription)
                    .accessibilityIdentifier("raise.amount")
                HStack(spacing: 12) {
                    if bounds.lowerBound < bounds.upperBound {
                        Slider(value: Binding(get: { Double(amount) }, set: {
                            amount = min(max(Int($0), bounds.lowerBound), bounds.upperBound)
                        }), in: Double(bounds.lowerBound)...Double(bounds.upperBound), step: 1)
                        .frame(minWidth: 44, minHeight: 52)
                        .tint(.white).accessibilityLabel(actionTitle)
                        .accessibilityValue("\(Chips.text(amount)) chips")
                        .accessibilityIdentifier("raise.slider")
                    } else {
                        Spacer(minLength: 0)
                    }
                    Button { submit(amount) } label: {
                        Image(systemName: "arrow.up").frame(width: 28)
                    }
                    .buttonStyle(RiverButtonStyle(prominent: true))
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(amountDescription)
                    .accessibilityIdentifier("raise.submit")
                }
        }
    }

    @ViewBuilder private var presets: some View {
        if bounds.lowerBound < bounds.upperBound {
            let half = min(max(bet + (pot + call) / 2, bounds.lowerBound), bounds.upperBound)
            let full = min(max(bet + pot + call, bounds.lowerBound), bounds.upperBound)
            if half != full { preset("1/2 pot", value: half, id: "raise.half") }
            if full != bounds.upperBound { preset("Pot", value: full, id: "raise.pot") }
            preset("All in", value: bounds.upperBound, id: "raise.allIn")
        } else {
            Spacer(minLength: 0)
        }
    }

    private var cancelButton: some View {
        Button(action: cancel) { Image(systemName: "xmark").frame(width: 28) }
            .buttonStyle(RiverButtonStyle())
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Cancel bet")
            .accessibilityIdentifier("raise.cancel")
    }

    private func preset(_ title: String, value: Int, id: String) -> some View {
        Button(title) {
            if amount != value {
                amount = value
                presetFeedback.toggle()
            }
        }
        .lineLimit(1).minimumScaleFactor(0.75)
        .buttonStyle(RiverButtonStyle())
        .accessibilityIdentifier(id)
        .accessibilityValue("\(Chips.text(value)) chips")
    }
}
