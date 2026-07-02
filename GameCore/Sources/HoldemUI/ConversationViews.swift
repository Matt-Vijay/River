import SwiftUI

#Preview("Start") {
    StartGameView(profileName: "Maverick",
                  profileAvatar: "🦊",
                  onStart: {},
                  onEditProfile: {})
}

#Preview("Compact") {
    CompactSummaryView(summary: "Flop · Pot 120 · jsven to act", onOpen: {})
        .frame(height: 80)
}

#Preview("Stale") {
    StaleTableView(summary: "Flop · Pot 120 · Alice to act")
}
