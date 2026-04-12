 import SwiftUI

@main
struct RadioApp: App {
    var body: some Scene {
        // Use 'Window' instead of 'WindowGroup' for a single standalone instance
        Window("Radio", id: "main") {
            RadioUI()
                // This allows you to click and drag anywhere on the
                // black background to move the window.
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.plain) // Removes title bar and buttons
        .windowResizability(.contentSize) // Forces window to match your UI size
    }
}
