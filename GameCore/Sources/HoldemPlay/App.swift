import SwiftUI
import AppKit
import HoldemUI

@main
struct HoldemPlayApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("River") {
            GameTableScreen()
                .frame(width: 393, height: 852)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)
    }
}
