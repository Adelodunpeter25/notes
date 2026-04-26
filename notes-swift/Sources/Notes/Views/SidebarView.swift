import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedFolderId: String?
    @Binding var selectedNoteId: String?

    var body: some View {
        List(selection: $selectedFolderId) {
            Label("All Notes", systemImage: "note.text")
                .tag(String?.none)

            Section("Folders") {
                ForEach(store.folders) { folder in
                    Label(folder.name, systemImage: "folder")
                        .tag(Optional(folder.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                store.deleteFolder(id: folder.id)
                                if selectedFolderId == folder.id {
                                    selectedFolderId = nil
                                    selectedNoteId = nil
                                }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem {
                Button(action: createFolder) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        }
    }

    private func createFolder() {
        let folder = Folder(name: "New Folder")
        store.upsertFolder(folder)
    }
}
