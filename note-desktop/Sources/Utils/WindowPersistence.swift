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
        UserDefaults.standard.set(
            [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height],
            forKey: key
        )
    }

    private func loadFrame() -> NSRect? {
        guard let array = UserDefaults.standard.array(forKey: key),
              array.count == 4,
              let x = array[0] as? CGFloat,
              let y = array[1] as? CGFloat,
              let w = array[2] as? CGFloat,
              let h = array[3] as? CGFloat else { return nil }
        let frame = NSRect(x: x, y: y, width: w, height: h)
        guard let visible = NSScreen.visibleFrame(for: frame) else { return nil }
        return visible.intersects(frame) ? frame : nil
    }
}

private extension NSScreen {
    static func visibleFrame(for frame: NSRect) -> NSRect? {
        for screen in NSScreen.screens where screen.visibleFrame.intersects(frame) {
            return screen.visibleFrame
        }
        return NSScreen.main?.visibleFrame
    }
}
