import SwiftUI

@main
struct RadioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 200, height: 400)
    }
}

// MARK: - AppDelegate: window chrome setup

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }

            // Fixed size
            window.setContentSize(NSSize(width: 200, height: 400))
            window.minSize = NSSize(width: 200, height: 400)
            window.maxSize = NSSize(width: 200, height: 400)

            // Borderless look: keep .titled so the window appears in Mission Control,
            // but hide all chrome.
            window.styleMask = [.titled, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(hex: "#C8C8C8")

            // Hide traffic-light buttons
            window.standardWindowButton(.closeButton)?.isHidden      = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden        = true

            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
