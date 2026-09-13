import SwiftUI
import RiverUI

@main
struct RiverApp: App {
    @State private var session = RiverSession(
        isLocal: true, resetProfile: ProcessInfo.processInfo.arguments.contains("-riverResetProfile"))

    var body: some Scene {
        WindowGroup { RiverRoot(session: session) }
    }
}
