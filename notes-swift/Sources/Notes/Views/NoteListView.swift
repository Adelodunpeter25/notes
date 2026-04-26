import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var store: AppStore
    let folderId: String?
    @Binding var selectedNoteId: String?
    @State private var deletingNoteId: String? = nil

    private var notes: [Note] {
        store.notes
            .filter { $0.deletedAt == nil && (folderId == nil || $0.folderId == folderId) }
            .sorted { ($0.isPinned ? 1 : 0, $0.updatedAt) > ($1.isPinned ? 1 : 0, $1.updatedAt) }
    }

    private var folderName: String {
        guard let folderId else { return "All Notes" }
        return store.folders.first { $0.id == folderId }?.name ?? "All Notes"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(folderName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: createNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.122, green: 0.122, blue: 0.122)) // ~#1f1f1f
            
            Divider().opacity(0.2)

            if notes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 20))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("No notes yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(notes) { note in
                            NoteRow(
                                note: note,
                                isSelected: selectedNoteId == note.id,
                                showFolder: folderId == nil,
                                folderName: store.folders.first { $0.id == note.folderId }?.name
                            )
                            .onTapGesture { selectedNoteId = note.id }
                            .contextMenu {
                                Button(note.isPinned ? "Unpin" : "Pin") {
                                    var updated = note
                                    updated.isPinned = !note.isPinned
                                    updated.updatedAt = Date()
                                    store.upsertNote(updated)
                                }
                                if !store.folders.isEmpty {
                                    Menu("Move to Folder") {
                                        ForEach(store.folders.filter { $0.id != note.folderId }) { folder in
                                            Button(folder.name) {
                                                var updated = note
                                                updated.folderId = folder.id
                                                updated.updatedAt = Date()
                                                store.upsertNote(updated)
                                            }
                                        }
                                    }
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    deletingNoteId = note.id
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Color(red: 0.122, green: 0.122, blue: 0.122))
        .alert("Move to Trash?", isPresented: Binding(get: { deletingNoteId != nil }, set: { if !$0 { deletingNoteId = nil } })) {
            Button("Move to Trash", role: .destructive) {
                if let id = deletingNoteId { store.softDeleteNote(id: id) }
                if selectedNoteId == deletingNoteId { selectedNoteId = nil }
                deletingNoteId = nil
            }
            Button("Cancel", role: .cancel) { deletingNoteId = nil }
        }
    }

    private func createNote() {
        let note = Note(folderId: folderId)
        store.upsertNote(note)
        selectedNoteId = note.id
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    let showFolder: Bool
    let folderName: String?

    private var title: String { note.title.isEmpty ? "Untitled" : note.title }
    private var preview: String { String(note.content.prefix(60)).replacingOccurrences(of: "\n", with: " ") }
    private var dateStr: String { note.updatedAt.formatted(.relative(presentation: .named)) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(dateStr)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    if !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .lineLimit(1)
                    }
                }

                if showFolder, let folderName {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .semibold))
                        Text(folderName)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.98, green: 0.79, blue: 0.2)) // accent yellow
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())

            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.98, green: 0.79, blue: 0.2))
                    .padding(.top, 10)
                    .padding(.trailing, 12)
            }
        }
    }
}
