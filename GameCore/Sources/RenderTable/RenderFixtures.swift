import SwiftUI
import GameCore
import HoldemUI

/// On-brand app icon: green spade on black.
struct IconView: View {
    var body: some View {
        ZStack {
            Color.black
            Text("\u{2660}")  // ♠
                .font(.system(size: 540, weight: .bold))
                .foregroundStyle(Color(red: 0.22, green: 0.85, blue: 0.5))
        }
    }
}

@MainActor
func seatRow() -> some View {
    func player(_ id: String, _ name: String, _ avatar: String, _ stack: Int,
                bet: Int = 0, status: PlayerStatus = .active) -> Player {
        var player = Player(id: id, name: name, avatar: avatar, stack: stack)
        player.bet = bet
        player.status = status
        return player
    }

    return HStack(alignment: .top, spacing: 8) {
        PlayerSeatView(player: player("a", "dante", "🧑🏿", 1000), isDealer: true)
        PlayerSeatView(player: player("b", "merry_ti", "🧑🏾", 266, bet: 20),
                       isActive: true,
                       turnStartedAt: Date().addingTimeInterval(-9), turnDuration: 30)
        PlayerSeatView(player: player("c", "jsven", "🧑🏻", 138, bet: 60),
                       lastActionLabel: "Raise")
        PlayerSeatView(player: player("d", "great_e", "🧑🏽", 0, status: .folded))
        PlayerSeatView(player: player("e", "verbice", "🐱", 408), highlightWin: true)
        EmptySeatView()
    }
    .padding(20)
    .frame(width: 600, height: 150)
    .background(Color.black)
}
