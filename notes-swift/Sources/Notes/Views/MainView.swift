import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedFolderId: String? = nil
    @State private var selectedNoteId: String? = nil

    var body: some View {
        NavigationView {
            SidebarView(selectedFolderId: $selectedFolderId, selectedNoteId: $selectedNoteId)
                .frame(minWidth: 180, idealWidth: 200)

            NoteListView(folderId: selectedFolderId, selectedNoteId: $selectedNoteId)
                .frame(minWidth: 220, idealWidth: 260)

            NoteEditorView(noteId: selectedNoteId)
                .frame(minWidth: 400)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
