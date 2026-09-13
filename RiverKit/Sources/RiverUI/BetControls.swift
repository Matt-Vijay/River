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
        VStack(spacing: 12) {
            Text(statusTitle)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(textSize.isAccessibilitySize ? 2 : 1, reservesSpace: true).truncationMode(.middle)
                .frame(maxWidth: .infinity, minHeight: statusHeight)
                .accessibilityLabel(reveal != nil ? "\(statusTitle). Hand hidden." : table.hand?.isComplete == true && !needsReentry ? table.summary : statusTitle)
                .accessibilityHidden(legal != nil && reveal == nil)
                .accessibilityIdentifier(reveal != nil ? "table.handoff" : table.hand?.isComplete == true ? "table.result" : "table.waiting")
            actions
                .lineLimit(2).truncationMode(.middle)
                .frame(height: (betContentHeight + 24) * (textSize.isAccessibilitySize ? 3 : 1)
                       + (textSize.isAccessibilitySize ? 20 : 0), alignment: .top)
        }
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
        betButton(legal.canCheck ? "Check" : "Call", amount: legal.canCheck ? nil : legal.call, id: "table.call") {
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

    private func betButton(_ title: String, amount: Int? = nil, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).lineLimit(1).minimumScaleFactor(0.8).frame(height: titleHeight)
                Text(amount.map(Chips.text) ?? " ").font(.subheadline.monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .frame(height: amountHeight)
                    .accessibilityHidden(amount == nil)
            }
            .frame(minHeight: betContentHeight)
        }
        .buttonStyle(RiverButtonStyle())
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
}

struct RaiseSheet: View {
    let bounds: ClosedRange<Int>
    let call: Int
    let bet: Int
    let pot: Int
    let submit: (Int) -> Void
    @State private var amount: Int
    @State private var presetFeedback = false
    @ScaledMetric(relativeTo: .largeTitle) private var amountHeight: CGFloat = 44
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    private var actionTitle: String { bet == 0 ? "Bet" : "Raise to" }
    private var amountDescription: String { "\(actionTitle) \(Chips.text(amount)) chips" }

    init(bounds: ClosedRange<Int>, call: Int, bet: Int, pot: Int, submit: @escaping (Int) -> Void) {
        self.bounds = bounds
        self.call = call
        self.bet = bet
        self.pot = pot
        self.submit = submit
        _amount = State(initialValue: bounds.lowerBound)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(Chips.text(amount)).font(.largeTitle.weight(.semibold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(height: amountHeight)
                        .accessibilityLabel(amountDescription)
                        .accessibilityIdentifier("raise.amount")
                    if bounds.lowerBound < bounds.upperBound {
                        Slider(value: Binding(get: { Double(amount) }, set: { amount = Int($0) }),
                               in: Double(bounds.lowerBound)...Double(bounds.upperBound), step: 1)
                            .tint(.white).accessibilityLabel(actionTitle).accessibilityValue("\(Chips.text(amount)) chips")
                            .accessibilityIdentifier("raise.slider")
                        let presets = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                        presets {
                            let half = min(max(bet + (pot + call) / 2, bounds.lowerBound), bounds.upperBound)
                            let full = min(max(bet + pot + call, bounds.lowerBound), bounds.upperBound)
                            if half != full { preset("Half pot", value: half, id: "raise.half") }
                            if full != bounds.upperBound { preset("Pot", value: full, id: "raise.pot") }
                            preset("All in", value: bounds.upperBound, id: "raise.allIn")
                        }
                    }
                    Button {
                        submit(amount)
                        dismiss()
                    } label: {
                        let label = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 4))
                        label {
                            Text(actionTitle)
                            Text(Chips.text(amount)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                        }
                    }
                    .buttonStyle(RiverButtonStyle(prominent: true))
                    .accessibilityLabel(amountDescription)
                    .accessibilityIdentifier("raise.submit")
                }
                .padding(24)
                .foregroundStyle(.primary)
            }
            .background(Color.black)
            .navigationTitle(actionTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).accessibilityIdentifier("raise.cancel")
                }
            }
        }
        .presentationDetents(textSize.isAccessibilitySize ? [.large] : [.height(360), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.black)
        .sensoryFeedback(.selection, trigger: presetFeedback)
    }

    private func preset(_ title: String, value: Int, id: String) -> some View {
        ActionButton(title: title, id: id, prominent: false) {
            if amount != value {
                amount = value
                presetFeedback.toggle()
            }
        }
    }
}
