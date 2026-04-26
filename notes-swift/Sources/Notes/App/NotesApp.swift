import SwiftUI

@main
struct NotesApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var appStore = AppStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authStore)
                .environmentObject(appStore)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }
    }
}
