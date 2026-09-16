import Poker
import SwiftUI

struct LobbyScreen: View {
    let session: RiverSession
    let table: Poker.Table
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        GeometryReader { geometry in
            lobby(wide: geometry.size.width >= 650 && geometry.size.width > geometry.size.height)
        }
    }

    private func lobby(wide: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                let details = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 16))
                details {
                        Text("\(table.seats.count) of \(table.rules.capacity) players")
                        Text("\(Chips.text(table.rules.smallBlind)) / \(Chips.text(table.rules.bigBlind)) blinds")
                }
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(table.seats) { seat in
                        HStack(spacing: 14) {
                            Avatar(text: seat.profile.avatar, size: 48).background(.primary.opacity(0.04), in: Circle())
                            let layout =
                                textSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                                : AnyLayout(HStackLayout(spacing: 8))
                            layout {
                                Text(seat.profile.name).font(.headline).lineLimit(textSize.isAccessibilitySize ? nil : 2)
                                    .minimumScaleFactor(0.8)
                                if !textSize.isAccessibilitySize { Spacer(minLength: 8) }
                                Text(Chips.text(seat.chips)).font(.subheadline.monospacedDigit()).foregroundStyle(
                                    .secondary
                                )
                                .lineLimit(1).minimumScaleFactor(0.5)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 68).accessibilityElement(children: .combine)
                        .accessibilityIdentifier("lobby.seat.\(seat.id)")
                        if seat.id != table.seats.last?.id { Divider().padding(.leading, 62) }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .clipped()
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Brand()
                Spacer()
                if !session.isLocal, table.seat(session.localID) != nil {
                    LeaveButton(session: session, table: table)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
            .avoidingWindowControls()
        }
        .safeAreaInset(edge: .bottom) {
            let layout = wide ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))
            layout {
                if session.isLocal {
                    Button(action: session.addGuest) {
                        Label("Add player", systemImage: "person.badge.plus")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                    }
                    .disabled(table.isFull)
                    .opacity(table.isFull ? 0 : 1)
                    .accessibilityHidden(table.isFull)
                    .accessibilityIdentifier(table.isFull ? "" : "lobby.addPlayer")
                }
                ActionButton(
                    title: "Start game", id: "lobby.startGame",
                    isEnabled: table.canDeal && table.seat(session.localID) != nil
                ) {
                    session.act(.deal(seed: UInt64.random(in: .min ... .max)), on: table)
                }
            }
            .padding(24).background(Color.black)
        }
        .frame(maxWidth: wide ? .infinity : 560)
        .frame(maxWidth: .infinity)
    }
}
