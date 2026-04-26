import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {}
                .keyboardShortcut("n", modifiers: .command)
            Button("New Folder") {}
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
