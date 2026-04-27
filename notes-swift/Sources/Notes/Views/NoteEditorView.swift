import SwiftUI
import RichTextKit
import Combine

struct NoteEditorView: View {
    @EnvironmentObject var store: AppStore
    let noteId: String?

    @StateObject private var richTextContext = RichTextContext()

    // The attributed string the editor is bound to.
    // We use @State so SwiftUI owns the storage lifetime.
    @State private var editorText: NSAttributedString = NSAttributedString(string: "")

    // Track which note ID we have loaded so we know when to flush/reload.
    @State private var loadedNoteId: String? = nil

    // Debounced auto-save cancellable.
    @State private var saveCancellable: AnyCancellable? = nil

    private var note: Note? {
        guard let noteId else { return nil }
        return store.notes.first { $0.id == noteId }
    }

    private var noteDateLabel: String {
        guard let note else { return "" }
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: note.updatedAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            if note != nil {
                EditorToolbarView(context: richTextContext)

                ScrollView {
                    VStack(spacing: 8) {
                        Text(noteDateLabel)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textMuted.opacity(0.7))
                            .padding(.top, 20)

                        // No .id() modifier here — we drive content changes via
                        // richTextContext.setAttributedString(to:) so the editor
                        // is never torn down on note switch, avoiding the
                        // "initialised with stale content" timing race.
                        RichTextEditor(
                            text: Binding(
                                get: { editorText },
                                set: { newVal in
                                    editorText = newVal
                                    scheduleAutoSave(for: noteId)
                                }
                            ),
                            context: richTextContext
                        ) { view in
                            #if os(macOS)
                            if let tv = view as? NSTextView {
                                tv.textColor              = .white
                                tv.insertionPointColor    = .white
                                tv.drawsBackground        = false
                                tv.isRichText             = true
                                tv.isEditable             = true
                                tv.isSelectable           = true
                                tv.allowsUndo             = true
                                tv.isVerticallyResizable  = true
                                tv.isHorizontallyResizable = false
                                tv.textContainer?.widthTracksTextView = true
                                tv.font = .systemFont(ofSize: 16)
                            }
                            #endif
                        }
                        .frame(minHeight: 500)
                    }
                    .padding(.horizontal, 40)
                    .maxSize4xl()
                }
            } else {
                EmptyStateView()
            }
        }
        .background(Theme.background)
        // Fire on first appear AND whenever noteId changes.
        .onAppear { switchNote(to: noteId) }
        .onChange(of: noteId) { newId in switchNote(to: newId) }
    }

    // MARK: - Note switching

    private func switchNote(to newId: String?) {
        // Guard: nothing to do if we're already showing this note.
        guard newId != loadedNoteId else { return }

        // 1. Flush any pending debounced save for the note we're leaving.
        flushSave(for: loadedNoteId)

        loadedNoteId = newId

        // 2. Load content for the new note.
        let attrString: NSAttributedString
        if let newId, let n = store.notes.first(where: { $0.id == newId }) {
            attrString = loadAttributedString(from: n)
        } else {
            attrString = NSAttributedString(string: "")
        }

        // Update our @State — this triggers a re-render of the Binding.get path.
        editorText = attrString

        // Also push directly into the RichTextKit context so the live NSTextView
        // reflects the change without needing the view to be recreated.
        richTextContext.setAttributedString(to: attrString)
    }

    // MARK: - Persistence helpers

    /// Decode RTF data stored in the note, falling back to plain text.
    private func loadAttributedString(from note: Note) -> NSAttributedString {
        let content = note.content
        // If it was saved as base64-encoded RTF, decode it.
        if content.hasPrefix("rtf:"),
           let data = Data(base64Encoded: String(content.dropFirst(4))) {
            if let attr = NSAttributedString(rtf: data, documentAttributes: nil) {
                return attr
            } else if let attr = NSAttributedString(rtfd: data, documentAttributes: nil) {
                return attr
            }
        }
        
        let fallbackText = content.hasPrefix("rtf:") ? "" : content
        // Plain-text fallback (old notes / first run).
        return NSAttributedString(
            string: fallbackText,
            attributes: [.font: NSFont.systemFont(ofSize: 16),
                         .foregroundColor: NSColor.white])
    }

    /// Encode an attributed string to RTF, prefixed with "rtf:" so we can detect it on load.
    private func encodeAttributedString(_ attr: NSAttributedString) -> String {
        if let data = attr.rtf(
            from: NSRange(location: 0, length: attr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            return "rtf:" + data.base64EncodedString()
        }
        // Fallback to plain text if RTF encoding fails.
        return attr.string
    }

    // MARK: - Auto-save

    /// Schedule a debounced save, capturing the note ID right now so it
    /// cannot drift to a different note if the user switches mid-timer.
    private func scheduleAutoSave(for idAtCallTime: String?) {
        saveCancellable?.cancel()
        let capturedId = idAtCallTime
        let capturedText = editorText          // snapshot the content too
        saveCancellable = Just(())
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { _ in
                performSave(id: capturedId, text: capturedText)
            }
    }

    /// Flush any pending debounced save immediately.
    private func flushSave(for id: String?) {
        saveCancellable?.cancel()
        saveCancellable = nil
        performSave(id: id, text: editorText)
    }

    /// Write `text` back to the store for the given note ID.
    private func performSave(id: String?, text: NSAttributedString) {
        guard let id,
              var updated = store.notes.first(where: { $0.id == id }) else { return }

        let newContent = encodeAttributedString(text)
        let newTitle   = TextFormatter.deriveTitle(from: text.string)

        guard updated.content != newContent || updated.title != newTitle else { return }

        updated.content   = newContent
        updated.title     = newTitle
        updated.updatedAt = Date()
        store.upsertNote(updated)
    }
}

// MARK: - View helpers

extension View {
    func maxSize4xl() -> some View {
        self.frame(maxWidth: 896)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Editor toolbar

private struct EditorToolbarView: View {
    @ObservedObject var context: RichTextContext

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ToolbarButton(systemName: "bold",          isActive: context.isBold)          { context.isBold.toggle() }
                ToolbarButton(systemName: "italic",        isActive: context.isItalic)        { context.isItalic.toggle() }
                ToolbarButton(systemName: "underline",     isActive: context.isUnderlined)    { context.isUnderlined.toggle() }
                ToolbarButton(systemName: "strikethrough", isActive: context.isStrikethrough) { context.isStrikethrough.toggle() }
            }

            Divider().frame(height: 16).opacity(0.2)

            HStack(spacing: 4) {
                ToolbarButton(systemName: "list.bullet", isActive: false) { }
                ToolbarButton(systemName: "list.number", isActive: false) { }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .border(Color.white.opacity(0.05), width: 1)
    }
}

private struct ToolbarButton: View {
    let systemName: String
    let isActive: Bool
    var activeColor: Color = Color.white.opacity(0.15)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(isActive ? Color.white.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Select a note to view or edit")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
