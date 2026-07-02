import SwiftUI
import GameCore

struct LobbyHeader: View {
    let lobby: Lobby

    var body: some View {
        VStack(spacing: 4) {
            Text("Table")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            Text("\(lobby.seats.count)/\(lobby.maxPlayers) players · \(lobby.readyCount) ready")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.top, 12)
    }
}
