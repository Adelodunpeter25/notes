import SwiftUI
import RichTextKit

struct NoteEditorView: View {
    @EnvironmentObject var store: AppStore
    let noteId: String?

    @State private var richText = NSAttributedString(string: "")
    @StateObject private var richTextContext = RichTextContext()

    private var note: Note? {
        guard let noteId else { return nil }
        return store.notes.first { $0.id == noteId }
    }

    var body: some View {
        if note != nil {
            HSplitView {
                RichTextEditor(text: $richText, context: richTextContext)
                    .padding(16)
                    .onChange(of: richText) { newValue in
                        guard var updated = note else { return }
                        updated.content = newValue.string
                        updated.updatedAt = Date()
                        store.upsertNote(updated)
                    }

                RichTextFormatSidebar(context: richTextContext)
                    .frame(width: 220)
            }
            .onAppear { richText = NSAttributedString(string: note?.content ?? "") }
            .onChange(of: noteId) { _ in
                richText = NSAttributedString(string: note?.content ?? "")
            }
        } else {
            VStack {
                Spacer()
                Text("Select a Note")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}
