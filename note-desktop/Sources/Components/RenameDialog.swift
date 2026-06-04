import AppKit

public final class RenameDialog {
    /// Displays a folder renaming prompt with an input text field.
    public static func show(
        title: String = "Rename Folder",
        message: String = "Enter the new name for the folder:",
        initialValue: String = "",
        placeholder: String = "Folder Name",
        onConfirm: @escaping (String) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        inputTextField.stringValue = initialValue
        inputTextField.placeholderString = placeholder
        alert.accessoryView = inputTextField
        
        // Show the alert sheet modally
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                onConfirm(name)
            }
        }
    }
}
