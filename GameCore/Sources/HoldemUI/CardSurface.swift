import SwiftUI

/// White rounded card body with soft shadow, shared by face and back.
struct CardSurface<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    var isBack: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
            .fill(isBack ? Theme.cardBackTint : Theme.cardFace)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
            )
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
            .frame(width: width, height: height)
    }
}
