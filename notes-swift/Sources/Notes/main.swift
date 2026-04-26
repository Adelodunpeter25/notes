import AppKit

let delegate = AppDelegate()
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.delegate = delegate
NSApplication.shared.activate(ignoringOtherApps: true)
NSApplication.shared.run()
