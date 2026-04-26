import AppKit

// AppDelegate is @MainActor so we assign it on the main thread via NSApplication.shared
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.delegate = AppDelegate()
NSApplication.shared.activate(ignoringOtherApps: true)
NSApplication.shared.run()
