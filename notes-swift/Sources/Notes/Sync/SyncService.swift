import Foundation

@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false

    private let api = APIClient.shared
    private let state = SyncStateStore.shared
    private let store: AppStore

    init(store: AppStore = .shared) {
        self.store = store
    }

    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let cursor = state.cursor
            let ops = buildOps(since: cursor)
            let request = SyncRequest(cursor: cursor, ops: ops)
            let response: SyncResponse = try await api.post("/sync", body: request)
            applyServerChanges(response)
            state.cursor = response.nextCursor
        } catch {
            print("[sync] failed: \(error)")
        }
    }

    // MARK: - Build outbound ops

    private func buildOps(since cursorString: String?) -> [SyncOperation] {
        let cursor = cursorString.flatMap { ISO8601DateFormatter().date(from: $0) }
        let iso = ISO8601DateFormatter()
        var ops: [SyncOperation] = []

        for note in store.notes {
            guard cursor == nil || note.updatedAt > cursor! else { continue }
            let updatedAt = iso.string(from: note.updatedAt)
            if note.deletedAt != nil {
                ops.append(SyncOperation(id: UUID().uuidString, type: "delete", entityType: "note", entityId: note.id, updatedAt: updatedAt, payload: nil))
            } else {
                ops.append(SyncOperation(id: UUID().uuidString, type: "upsert", entityType: "note", entityId: note.id, updatedAt: updatedAt, payload: [
                    "title": AnyCodable(value: note.title),
                    "content": AnyCodable(value: note.content),
                    "isPinned": AnyCodable(value: note.isPinned),
                    "folderId": AnyCodable(value: note.folderId as Any),
                ]))
            }
        }

        for folder in store.folders {
            guard cursor == nil || folder.updatedAt > cursor! else { continue }
            ops.append(SyncOperation(id: UUID().uuidString, type: "upsert", entityType: "folder", entityId: folder.id, updatedAt: iso.string(from: folder.updatedAt), payload: [
                "name": AnyCodable(value: folder.name),
            ]))
        }

        for task in store.tasks {
            guard cursor == nil || task.updatedAt > cursor! else { continue }
            let updatedAt = iso.string(from: task.updatedAt)
            if task.deletedAt != nil {
                ops.append(SyncOperation(id: UUID().uuidString, type: "delete", entityType: "task", entityId: task.id, updatedAt: updatedAt, payload: nil))
            } else {
                ops.append(SyncOperation(id: UUID().uuidString, type: "upsert", entityType: "task", entityId: task.id, updatedAt: updatedAt, payload: [
                    "title": AnyCodable(value: task.title),
                    "description": AnyCodable(value: task.taskDescription),
                    "isCompleted": AnyCodable(value: task.isCompleted),
                ]))
            }
        }

        return ops
    }

    // MARK: - Apply server changes

    private func applyServerChanges(_ response: SyncResponse) {
        let iso = ISO8601DateFormatter()

        for tombstone in response.deleted {
            if tombstone.entityType == "note",
               let idx = store.notes.firstIndex(where: { $0.id == tombstone.entityId }) {
                var note = store.notes[idx]
                note.deletedAt = iso.date(from: tombstone.deletedAt)
                store.upsertNote(note)
            }
        }

        for dto in response.notes {
            let serverUpdatedAt = iso.date(from: dto.updatedAt) ?? Date()
            let note = Note(id: dto.id, userId: dto.userId, folderId: dto.folderId,
                            title: dto.title, content: dto.content, isPinned: dto.isPinned,
                            createdAt: iso.date(from: dto.createdAt) ?? Date(),
                            updatedAt: serverUpdatedAt)
            if let existing = store.notes.first(where: { $0.id == dto.id }),
               existing.updatedAt >= serverUpdatedAt { continue }
            store.upsertNote(note)
        }

        for dto in response.folders {
            let serverUpdatedAt = iso.date(from: dto.updatedAt) ?? Date()
            if let existing = store.folders.first(where: { $0.id == dto.id }),
               existing.updatedAt >= serverUpdatedAt { continue }
            store.upsertFolder(Folder(id: dto.id, userId: dto.userId, name: dto.name,
                                     createdAt: iso.date(from: dto.createdAt) ?? Date(),
                                     updatedAt: serverUpdatedAt))
        }

        for dto in response.tasks {
            let serverUpdatedAt = iso.date(from: dto.updatedAt) ?? Date()
            if let existing = store.tasks.first(where: { $0.id == dto.id }),
               existing.updatedAt >= serverUpdatedAt { continue }
            store.upsertTask(NoteTask(id: dto.id, userId: dto.userId, title: dto.title,
                                     taskDescription: dto.description, isCompleted: dto.isCompleted,
                                     createdAt: iso.date(from: dto.createdAt) ?? Date(),
                                     updatedAt: serverUpdatedAt))
        }
    }
}
