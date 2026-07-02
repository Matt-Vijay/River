import SwiftUI

struct PlayerSeatMarker: View {
    var isActive: Bool
    var turnStartedAt: Date?
    var turnDuration: TimeInterval
    var lastActionLabel: String?

    var body: some View {
        ZStack {
            Color.clear.frame(width: 1, height: 18)
            marker
        }
    }

    @ViewBuilder
    private var marker: some View {
        if isActive, let turnStartedAt {
            CountdownTimer(startedAt: turnStartedAt, duration: turnDuration)
                .frame(width: 16, height: 16)
                .transition(.opacity)
        } else if let lastActionLabel {
            Text(lastActionLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .transition(.opacity)
        }
    }
}
