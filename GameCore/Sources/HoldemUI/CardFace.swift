import SwiftUI
import GameCore

/// Card face: rank in the top-left corner plus a large centred suit pip.
struct CardFace: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            Text(card.suit.symbol)
                .font(.system(size: width * 0.5, weight: .semibold))
                .foregroundStyle(card.suit.color)
                .offset(y: height * 0.08)

            Text(card.rank.label)
                .font(.system(size: width * 0.36, weight: .bold))
                .foregroundStyle(card.suit.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, width * 0.12)
                .padding(.vertical, height * 0.06)
        }
    }
}
