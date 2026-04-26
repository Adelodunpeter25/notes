import SwiftUI

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
                        count: nil
                    )
                    .onTapGesture { selectedFolderId = nil; selectedNoteId = nil }

                    // Folders
                    ForEach(store.folders) { folder in
                        if renamingFolderId == folder.id {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                TextField("", text: $renameText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .onSubmit { commitRename(folder) }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            SidebarRow(
                                icon: "folder",
                                label: folder.name,
                                isActive: selectedFolderId == folder.id,
                                count: store.notes.filter { $0.folderId == folder.id && $0.deletedAt == nil }.count
                            )
                            .onTapGesture { selectedFolderId = folder.id; selectedNoteId = nil }
                            .contextMenu {
                                Button("Rename") {
                                    renamingFolderId = folder.id
                                    renameText = folder.name
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    deletingFolder = folder
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer()

            // Bottom actions — Trash + New Folder
            VStack(spacing: 2) {
                Divider().opacity(0.15)
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .light))
                    Text("Trash")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())

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
        .background(Color(red: 0.169, green: 0.169, blue: 0.169)) // #2b2b2b
        .alert("Delete Folder?", isPresented: Binding(get: { deletingFolder != nil }, set: { if !$0 { deletingFolder = nil } })) {
            Button("Delete", role: .destructive) {
                if let f = deletingFolder { store.deleteFolder(id: f.id) }
                deletingFolder = nil
            }
            Button("Cancel", role: .cancel) { deletingFolder = nil }
        } message: {
            Text("All notes inside will be moved to All Notes.")
        }
    }

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
}

private struct SidebarRow: View {
    let icon: String
    let label: String
    let isActive: Bool
    let count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? .white : Color(nsColor: .secondaryLabelColor))
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? .white : Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)
            Spacer()
            if let count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isActive ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}
