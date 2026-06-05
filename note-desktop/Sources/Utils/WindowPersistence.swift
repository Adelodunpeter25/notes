import AppKit

public final class WindowPersistence: NSObject, NSWindowDelegate {
    private let key: String
    private var saveWorkItem: DispatchWorkItem?

    public init(key: String) {
        self.key = key
        super.init()
    }

    public func restoreFrame(for window: NSWindow) {
        guard let frame = loadFrame() else {
            window.center()
            return
        }
        window.setFrame(frame, display: true)
    }

    public func attach(to window: NSWindow) {
        window.delegate = self
        restoreFrame(for: window)
    }

    public func saveNow(for window: NSWindow) {
        saveWorkItem?.cancel()
        saveFrame(window.frame)
    }

    // MARK: - NSWindowDelegate

    public func windowDidMove(_ notification: Notification) {
        scheduleSave(notification)
    }

    public func windowDidResize(_ notification: Notification) {
        scheduleSave(notification)
    }

    // MARK: - Private

    private func scheduleSave(_ notification: Notification) {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  let window = notification.object as? NSWindow else { return }
            self.saveFrame(window.frame)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    private func saveFrame(_ frame: NSRect) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: key)
    }

    private func loadFrame() -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: key) else { return nil }
        let frame = NSRectFromString(frameString)
        if frame == .zero { return nil }
        
        // Ensure the window frame is still visible on some screen
        let isVisible = NSScreen.screens.contains { screen in
            screen.frame.intersects(frame)
        }
        return isVisible ? frame : nil
    }
}
