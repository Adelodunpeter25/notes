import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var authStore: AuthStore
    @State private var selectedFolderId: String? = nil
    @State private var selectedNoteId: String? = nil
    @State private var activeTab: AppTab = .notes
    @State private var isSyncing = false

    enum AppTab { case notes, tasks }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Titlebar
            TitlebarView(
                activeTab: $activeTab,
                isSyncing: isSyncing,
                onSync: { Task { await syncNow() } }
            )

            Divider().opacity(0.2)

            // Content
            HSplitView {
                SidebarView(
                    selectedFolderId: $selectedFolderId,
                    selectedNoteId: $selectedNoteId
                )
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 260)

                NoteListView(
                    folderId: selectedFolderId,
                    selectedNoteId: $selectedNoteId
                )
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)

                NoteEditorView(noteId: selectedNoteId)
                    .frame(minWidth: 400)
            }
        }
        .background(Color(red: 0.122, green: 0.122, blue: 0.122))
    }

    private func syncNow() async {
        isSyncing = true
        let service = SyncService()
        await service.syncNow()
        isSyncing = false
    }
}

private struct TitlebarView: View {
    @Binding var activeTab: MainView.AppTab
    let isSyncing: Bool
    let onSync: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer
            Spacer().frame(width: 80)

            Spacer()

            // Notes / Tasks toggle
            HStack(spacing: 6) {
                TabPill(label: "Notes", isActive: activeTab == .notes) {
                    activeTab = .notes
                }
                TabPill(label: "Tasks", isActive: activeTab == .tasks) {
                    activeTab = .tasks
                }
            }

            Spacer()

            // Right actions
            HStack(spacing: 2) {
                Button(action: onSync) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .rotationEffect(.degrees(isSyncing ? 360 : 0))
                        .animation(isSyncing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: isSyncing)
                        .foregroundColor(isSyncing ? Color(red: 0.98, green: 0.79, blue: 0.2) : Color(nsColor: .secondaryLabelColor))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Sync Now")

                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(Color(red: 0.173, green: 0.173, blue: 0.173)) // #2c2c2c
    }
}

private struct TabPill: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isActive ? .black : Color(nsColor: .secondaryLabelColor))
                .padding(.horizontal, 20)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color(red: 0.98, green: 0.79, blue: 0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isActive ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
