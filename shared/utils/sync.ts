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
  _tasks: any[], // Kept for signature compatibility if needed, but unused
  cursor: string | null,
): SyncOperation[] {
  const ops: SyncOperation[] = [];
  const since = cursor ? new Date(cursor) : null;

  for (const note of notes) {
    const updatedAt = note.updatedAt ?? note.createdAt ?? new Date().toISOString();
    if (since && new Date(updatedAt) < since) continue;

    // Filter out deleted items - they won't be synced to the server
    if (note.deletedAt) continue;

    ops.push({
      id: uuid(), type: 'upsert', entityType: 'note', entityId: note.id, updatedAt,
      payload: { folderId: note.folderId ?? null, title: note.title, content: note.content, isPinned: note.isPinned, createdAt: note.createdAt },
    });
  }

  for (const folder of folders) {
    const updatedAt = folder.updatedAt ?? folder.createdAt ?? new Date().toISOString();
    if (since && new Date(updatedAt) < since) continue;

    // Filter out deleted items
    if (folder.deletedAt) continue;

    ops.push({
      id: uuid(), type: 'upsert', entityType: 'folder', entityId: folder.id, updatedAt,
      payload: { name: folder.name, createdAt: folder.createdAt },
    });
  }

  return ops;
}
