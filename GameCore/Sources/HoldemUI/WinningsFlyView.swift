import SwiftUI

/// The won amount as a compact chip that travels toward the winner and fades.
struct WinningsFlyView: View {
    let fly: WinningsFly
    @State private var progress: CGFloat = 0

    private var endY: CGFloat { fly.toHero ? 280 : -300 }

    var body: some View {
        Text("+\(ChipFormatter.string(fly.amount))")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.chip)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.chipBackground))
            .scaleEffect(1 - 0.45 * progress)
            .offset(y: endY * progress)
            .opacity(progress < 0.7 ? 1 : (1 - progress) / 0.3)
            .onAppear {
                progress = 0
                withAnimation(.timingCurve(0.33, 0.0, 0.2, 1.0, duration: 0.55)) {
                    progress = 1
                }
            }
            .allowsHitTesting(false)
    }
}
