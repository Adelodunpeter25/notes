import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedFolderId: String?
    @Binding var selectedNoteId: String?

    @State private var renamingFolderId: String? = nil
    @State private var renameText = ""
    @State private var deletingFolder: Folder? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    // All Notes
                    SidebarRow(
                        icon: "folder",
                        label: "All Notes",
                        isActive: selectedFolderId == nil,
                        count: store.notes.filter { $0.deletedAt == nil }.count
                    )
                    .onTapGesture { selectedFolderId = nil; selectedNoteId = nil }

                    Divider()
                        .padding(.vertical, 4)
                        .opacity(0.15)

                    // Folders
                    ForEach(store.folders) { folder in
                        if renamingFolderId == folder.id {
                            // ── Inline rename row ──
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.accent)

                                TextField("Folder name", text: $renameText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.textInactive)
                                    .onSubmit { commitRename(folder) }
                                    .onExitCommand { cancelRename() }
                                    .introspectTextField { $0.becomeFirstResponder() }

                                Spacer()

                                // Confirm / cancel buttons
                                Button { commitRename(folder) } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.accent)
                                }
                                .buttonStyle(.plain)

                                Button { cancelRename() } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Theme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Theme.sidebarBackground)
                            .cornerRadius(6)
                        } else {
                            // ── Normal folder row ──
                            SidebarRow(
                                icon: "folder",
                                label: folder.name,
                                isActive: selectedFolderId == folder.id,
                                count: store.notes.filter { $0.folderId == folder.id && $0.deletedAt == nil }.count
                            )
                            .onTapGesture { selectedFolderId = folder.id; selectedNoteId = nil }
                            .contextMenu {
                                Button("Rename") {
                                    renameText = folder.name
                                    renamingFolderId = folder.id
                                }
                                Divider()
                                Button("Delete Folder", role: .destructive) {
                                    deletingFolder = folder
                                }
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)
                        .opacity(0.15)

                    // Trash
                    SidebarRow(
                        icon: "trash",
                        label: "Trash",
                        isActive: selectedFolderId == "trash",
                        count: store.notes.filter { $0.deletedAt != nil }.count
                    )
                    .onTapGesture { selectedFolderId = "trash"; selectedNoteId = nil }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer()

            // Bottom — New Folder button
            VStack(spacing: 2) {
                Button(action: createFolder) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 15, weight: .light))
                        Text("New Folder")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
        .background(Theme.sidebarBackground)
        // Listen for menu-triggered "New Folder" command
        .onReceive(NotificationCenter.default.publisher(for: .newFolderRequested)) { _ in
            createFolder()
        }
        .alert("Delete Folder?",
               isPresented: Binding(
                   get: { deletingFolder != nil },
                   set: { if !$0 { deletingFolder = nil } }
               )) {
            Button("Delete", role: .destructive) {
                if let f = deletingFolder { store.deleteFolder(id: f.id) }
                deletingFolder = nil
            }
            Button("Cancel", role: .cancel) { deletingFolder = nil }
        } message: {
            Text("All notes inside will be moved to All Notes.")
        }
    }

    // MARK: - Actions

    private func createFolder() {
        let folder = Folder(name: "New Folder")
        store.upsertFolder(folder)
        renamingFolderId = folder.id
        renameText = folder.name
    }

    private func commitRename(_ folder: Folder) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            var updated = folder
            updated.name = name
            updated.updatedAt = Date()
            store.upsertFolder(updated)
        }
        renamingFolderId = nil
    }

    private func cancelRename() {
        renamingFolderId = nil
        renameText = ""
    }
}

// MARK: - SidebarRow

private struct SidebarRow: View {
    let icon: String
    let label: String
    let isActive: Bool
    let count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? .white : Theme.accent)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isActive ? .white : Theme.textInactive)
                .lineLimit(1)
            Spacer()
            if let count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isActive ? .white : Theme.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isActive ? Theme.activeBackground : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

// MARK: - TextField introspection helper (no extra package needed)

private extension View {
    /// Focus the underlying NSTextField on appear using AppKit introspection.
    func introspectTextField(_ configure: @escaping (NSTextField) -> Void) -> some View {
        self.background(
            _TextFieldFocuser(configure: configure)
        )
    }
}

private struct _TextFieldFocuser: NSViewRepresentable {
    let configure: (NSTextField) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        // Walk up the responder chain to find the NSTextField sibling
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            func find(in view: NSView) -> NSTextField? {
                if let tf = view as? NSTextField { return tf }
                for sub in view.subviews {
                    if let found = find(in: sub) { return found }
                }
                return nil
            }
            if let tf = find(in: window.contentView ?? nsView) {
                configure(tf)
            }
        }
    }
}
