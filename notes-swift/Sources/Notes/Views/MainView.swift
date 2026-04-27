import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var authStore: AuthStore
    @StateObject private var syncService = SyncService()
    
    @State private var selectedFolderId: String? = nil
    @State private var selectedNoteId: String? = nil
    @State private var activeTab: AppTab = .notes

    // Persistence
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 200
    @AppStorage("noteListWidth") private var noteListWidth: Double = 260

    enum AppTab { case notes, tasks }

    var body: some View {
        HSplitView {
            SidebarView(
                selectedFolderId: $selectedFolderId,
                selectedNoteId: $selectedNoteId
            )
            .frame(minWidth: 150, idealWidth: CGFloat(sidebarWidth), maxWidth: 300)
            .background(
                GeometryReader { geo in
                    Color.clear.onChange(of: geo.size.width) { newValue in
                        sidebarWidth = Double(newValue)
                    }
                }
            )

            NoteListView(
                folderId: selectedFolderId,
                selectedNoteId: $selectedNoteId
            )
            .frame(minWidth: 200, idealWidth: CGFloat(noteListWidth), maxWidth: 400)
            .background(
                GeometryReader { geo in
                    Color.clear.onChange(of: geo.size.width) { newValue in
                        noteListWidth = Double(newValue)
                    }
                }
            )

            NoteEditorView(noteId: selectedNoteId)
                .frame(minWidth: 400, maxWidth: .infinity)
                .layoutPriority(1)
        }
        .background(Theme.background)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("View", selection: $activeTab) {
                    Text("Notes").tag(AppTab.notes)
                    Text("Tasks").tag(AppTab.tasks)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await syncService.syncNow() } }) {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
                .help("Sync Now")
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {}) {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
            }
        }
        .task {
            // Initial sync on first load
            await syncService.syncNow()
        }
    }
}
