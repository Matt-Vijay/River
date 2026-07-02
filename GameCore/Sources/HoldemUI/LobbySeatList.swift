import SwiftUI
import GameCore

struct LobbySeatList: View {
    let seats: [LobbySeat]
    let localID: String

    var body: some View {
        VStack(spacing: 10) {
            ForEach(seats) { seat in
                LobbySeatRow(seat: seat, isLocal: seat.id == localID)
            }
        }
    }
}

private struct LobbySeatRow: View {
    let seat: LobbySeat
    let isLocal: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(seat.avatar).font(.system(size: 30))
            Text(seat.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
            Spacer()
            readiness
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isLocal ? Theme.accent.opacity(0.8) : .clear, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let owner = isLocal ? "You, " : ""
        let readiness = seat.isReady ? "Ready" : "Not ready"
        return "\(owner)\(seat.name), \(readiness)"
    }

    @ViewBuilder
    private var readiness: some View {
        if seat.isReady {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .labelStyle(.titleAndIcon)
        } else {
            Label("Not ready", systemImage: "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .labelStyle(.titleAndIcon)
        }
    }
}
