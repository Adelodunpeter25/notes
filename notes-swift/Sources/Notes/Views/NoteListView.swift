import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var store: AppStore
    let folderId: String?
    @Binding var selectedNoteId: String?
    @State private var deletingNoteId: String? = nil

    private var notes: [Note] {
        if folderId == "trash" {
            return store.notes
                .filter { $0.deletedAt != nil }
                .sorted { $0.updatedAt > $1.updatedAt }
        }
        
        return store.notes
            .filter { $0.deletedAt == nil && (folderId == nil || $0.folderId == folderId) }
            .sorted { ($0.isPinned ? 1 : 0, $0.updatedAt) > ($1.isPinned ? 1 : 0, $1.updatedAt) }
    }

    private var folderName: String {
        if folderId == "trash" { return "Trash" }
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
            .background(Theme.surface)
            
            Divider().opacity(0.2)

            if notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: folderId == "trash" ? "trash" : "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                    Text(folderId == "trash" ? "Trash is Empty" : "No notes yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                    if folderId != "trash" {
                        Text("Create your first note to get started.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(notes) { note in
                            NoteRow(
                                note: note,
                                isSelected: selectedNoteId == note.id,
                                showFolder: folderId == nil,
                                folderName: store.folders.first { $0.id == note.folderId }?.name
                            )
                            .onTapGesture { selectedNoteId = note.id }
                            .contextMenu {
                                // ... context menu same as before
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
                            
                            Divider()
                                .padding(.horizontal, 12)
                                .opacity(0.1)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Theme.surface)
        .alert("Move to Trash?", isPresented: Binding(get: { deletingNoteId != nil }, set: { if !$0 { deletingNoteId = nil } })) {
            Button("Move to Trash", role: .destructive) {
                if let id = deletingNoteId { store.softDeleteNote(id: id) }
                if selectedNoteId == deletingNoteId { selectedNoteId = nil }
                deletingNoteId = nil
            }
            Button("Cancel", role: .cancel) { deletingNoteId = nil }
        }
        // Handle Cmd+N from the menu bar
        .onReceive(NotificationCenter.default.publisher(for: .newNoteRequested)) { _ in
            // Only create a note when this list is visible (not in trash view)
            guard folderId != "trash" else { return }
            createNote()
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
    private var preview: String { 
        let plain = TextFormatter.extractPlainText(from: note.content)
        return String(plain.prefix(60)).replacingOccurrences(of: "\n", with: " ") 
    }
    private var dateStr: String { note.updatedAt.formatted(.relative(presentation: .named)) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(isSelected ? .white : .white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(dateStr)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white)
                    if !preview.isEmpty {
                        Text(preview)
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? Color.white.opacity(0.8) : Theme.textMuted)
                            .lineLimit(1)
                    }
                }

                if showFolder, let folderName {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 12, weight: .semibold))
                        Text(folderName)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(isSelected ? .white : Theme.accent)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.activeBackground : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())

            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : Theme.accent)
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
        }
    }
}
