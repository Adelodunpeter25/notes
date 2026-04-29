import type { SyncOperation } from '../types/sync';
import type { Note } from '../types/notes';
import type { Folder } from '../types/folders';
import type { Task } from '../types/tasks';

function uuid(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export function buildSyncOps(
  notes: Note[],
  folders: Folder[],
  tasks: Task[],
  cursor: string | null,
): SyncOperation[] {
  const ops: SyncOperation[] = [];
  const since = cursor ? new Date(cursor) : null;

  for (const note of notes) {
    const updatedAt = note.updatedAt ?? note.createdAt ?? new Date().toISOString();
    if (since && new Date(updatedAt) < since) continue;

    if (note.deletedAt) {
      ops.push({ id: uuid(), type: 'delete', entityType: 'note', entityId: note.id, updatedAt });
    } else {
      ops.push({
        id: uuid(), type: 'upsert', entityType: 'note', entityId: note.id, updatedAt,
        payload: { folderId: note.folderId ?? null, title: note.title, content: note.content, isPinned: note.isPinned, createdAt: note.createdAt },
      });
    }
  }

  for (const folder of folders) {
    const updatedAt = folder.updatedAt ?? folder.createdAt ?? new Date().toISOString();
    if (since && new Date(updatedAt) < since) continue;
    if (folder.deletedAt) {
      ops.push({ id: uuid(), type: 'delete', entityType: 'folder', entityId: folder.id, updatedAt });
    } else {
      ops.push({
        id: uuid(), type: 'upsert', entityType: 'folder', entityId: folder.id, updatedAt,
        payload: { name: folder.name, createdAt: folder.createdAt },
      });
    }
  }

  for (const task of tasks) {
    const updatedAt = task.updatedAt ?? task.createdAt ?? new Date().toISOString();
    if (since && new Date(updatedAt) < since) continue;

    if (task.deletedAt) {
      ops.push({ id: uuid(), type: 'delete', entityType: 'task', entityId: task.id, updatedAt });
    } else {
      ops.push({
        id: uuid(), type: 'upsert', entityType: 'task', entityId: task.id, updatedAt,
        payload: { title: task.title, description: task.description, isCompleted: task.isCompleted, dueDate: task.dueDate ?? null, createdAt: task.createdAt },
      });
    }
  }

  return ops;
}
