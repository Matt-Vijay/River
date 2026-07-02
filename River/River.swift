import SwiftUI
import HoldemUI

@main
struct River: App {
    var body: some Scene {
        WindowGroup {
            GameTableScreen()
                .preferredColorScheme(.dark)
        }
    }
}
