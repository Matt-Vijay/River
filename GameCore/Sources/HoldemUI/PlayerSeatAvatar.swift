import SwiftUI

struct PlayerSeatAvatar: View {
    let avatar: String
    var isDealer: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(avatar)
                .font(.system(size: 38))
                .frame(width: 50, height: 50)

            if isDealer {
                Text("D")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.white))
                    .transition(.opacity)
            }
        }
    }
}
