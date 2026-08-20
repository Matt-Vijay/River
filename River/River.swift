import SwiftUI
import HoldemUI

@main
struct River: App {
    var body: some Scene {
        WindowGroup {
            GameTableScreen(resetProfile: CommandLine.arguments.contains("-riverResetProfile"))
                .preferredColorScheme(.dark)
        }
    }
}
