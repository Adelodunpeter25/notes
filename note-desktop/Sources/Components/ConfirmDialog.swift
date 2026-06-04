import AppKit

public final class ConfirmDialog {
    /// Displays a standard modal confirmation dialog.
    public static func show(
        title: String,
        message: String,
        actionTitle: String = "Confirm",
        cancelTitle: String = "Cancel",
        onConfirm: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: cancelTitle)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            onConfirm()
        }
    }
}
