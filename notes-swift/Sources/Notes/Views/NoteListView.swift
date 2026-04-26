import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var store: AppStore
    let folderId: String?
    @Binding var selectedNoteId: String?

    private var notes: [Note] {
        store.notes.filter { folderId == nil || $0.folderId == folderId }
    }

    var body: some View {
        List(selection: $selectedNoteId) {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(note.content.isEmpty ? "No content" : note.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .tag(Optional(note.id))
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        store.softDeleteNote(id: note.id)
                        if selectedNoteId == note.id { selectedNoteId = nil }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: createNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private func createNote() {
        let note = Note(folderId: folderId)
        store.upsertNote(note)
        selectedNoteId = note.id
    }
}
