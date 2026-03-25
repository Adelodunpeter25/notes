import { eq, gt, and, isNotNull } from 'drizzle-orm';
import { db } from '@db/index';
import { notes, folders, tasks } from '@db/schema';
import type { SyncRequest, SyncResponse, SyncOperation, SyncTombstone } from '@types/index';

const MAX_RETRIES = 3;

async function withRetry<T>(fn: () => Promise<T>, retries = MAX_RETRIES): Promise<T> {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      const isRetryable =
        err?.code === '40001' || // serialization failure
        err?.code === '40P01' || // deadlock
        err?.message?.includes('deadlock') ||
        err?.message?.includes('serialization');

      if (!isRetryable || attempt === retries) throw err;
      await new Promise(r => setTimeout(r, 50 * attempt));
    }
  }
  throw new Error('unreachable');
}

async function processOp(userId: string, op: SyncOperation): Promise<void> {
  if (op.type === 'delete') {
    await processDelete(userId, op);
    return;
  }
  await processUpsert(userId, op);
}

async function processDelete(userId: string, op: SyncOperation): Promise<void> {
  const now = new Date();
  switch (op.entityType) {
    case 'note':
      await db.update(notes)
        .set({ deletedAt: now, updatedAt: now })
        .where(and(eq(notes.id, op.entityId), eq(notes.userId, userId)));
      break;
    case 'folder':
      await db.delete(folders)
        .where(and(eq(folders.id, op.entityId), eq(folders.userId, userId)));
      break;
    case 'task':
      await db.update(tasks)
        .set({ deletedAt: now, updatedAt: now })
        .where(and(eq(tasks.id, op.entityId), eq(tasks.userId, userId)));
      break;
  }
}

async function processUpsert(userId: string, op: SyncOperation): Promise<void> {
  const p = op.payload ?? {};
  const clientUpdatedAt = new Date(op.updatedAt);

  switch (op.entityType) {
    case 'note': {
      const existing = await db.query.notes.findFirst({
        where: and(eq(notes.id, op.entityId), eq(notes.userId, userId)),
      });

      if (existing) {
        // Conflict resolution: skip if server is newer
        if (existing.updatedAt > clientUpdatedAt) return;
        await db.update(notes)
          .set({
            folderId: (p.folderId as string | null) ?? existing.folderId,
            title: (p.title as string) ?? existing.title,
            content: (p.content as string) ?? existing.content,
            isPinned: (p.isPinned as boolean) ?? existing.isPinned,
            deletedAt: p.deletedAt ? new Date(p.deletedAt as string) : existing.deletedAt,
            updatedAt: clientUpdatedAt,
          })
          .where(and(eq(notes.id, op.entityId), eq(notes.userId, userId)));
      } else {
        await db.insert(notes).values({
          id: op.entityId,
          userId,
          folderId: (p.folderId as string | null) ?? null,
          title: (p.title as string) ?? 'Untitled',
          content: (p.content as string) ?? '',
          isPinned: (p.isPinned as boolean) ?? false,
          createdAt: p.createdAt ? new Date(p.createdAt as string) : new Date(),
          updatedAt: clientUpdatedAt,
        }).onConflictDoNothing();
      }
      break;
    }

    case 'folder': {
      const existing = await db.query.folders.findFirst({
        where: and(eq(folders.id, op.entityId), eq(folders.userId, userId)),
      });

      if (existing) {
        if (existing.updatedAt > clientUpdatedAt) return;
        await db.update(folders)
          .set({
            name: (p.name as string) ?? existing.name,
            updatedAt: clientUpdatedAt,
          })
          .where(and(eq(folders.id, op.entityId), eq(folders.userId, userId)));
      } else {
        await db.insert(folders).values({
          id: op.entityId,
          userId,
          name: (p.name as string) ?? 'Untitled Folder',
          createdAt: p.createdAt ? new Date(p.createdAt as string) : new Date(),
          updatedAt: clientUpdatedAt,
        }).onConflictDoNothing();
      }
      break;
    }

    case 'task': {
      const existing = await db.query.tasks.findFirst({
        where: and(eq(tasks.id, op.entityId), eq(tasks.userId, userId)),
      });

      if (existing) {
        if (existing.updatedAt > clientUpdatedAt) return;
        await db.update(tasks)
          .set({
            title: (p.title as string) ?? existing.title,
            description: (p.description as string) ?? existing.description,
            isCompleted: (p.isCompleted as boolean) ?? existing.isCompleted,
            dueDate: p.dueDate ? new Date(p.dueDate as string) : existing.dueDate,
            deletedAt: p.deletedAt ? new Date(p.deletedAt as string) : existing.deletedAt,
            updatedAt: clientUpdatedAt,
          })
          .where(and(eq(tasks.id, op.entityId), eq(tasks.userId, userId)));
      } else {
        await db.insert(tasks).values({
          id: op.entityId,
          userId,
          title: (p.title as string) ?? 'Untitled',
          description: (p.description as string) ?? '',
          isCompleted: (p.isCompleted as boolean) ?? false,
          dueDate: p.dueDate ? new Date(p.dueDate as string) : null,
          createdAt: p.createdAt ? new Date(p.createdAt as string) : new Date(),
          updatedAt: clientUpdatedAt,
        }).onConflictDoNothing();
      }
      break;
    }
  }
}

export async function sync(userId: string, req: SyncRequest): Promise<SyncResponse> {
  const processedOpIds: string[] = [];
  const errors: { opId: string; error: string }[] = [];

  // Process outbound ops with per-op retry
  for (const op of req.ops) {
    try {
      await withRetry(() => processOp(userId, op));
      processedOpIds.push(op.id);
    } catch (err: any) {
      // Don't fail the whole sync for one bad op — collect and continue
      errors.push({ opId: op.id, error: err.message ?? 'unknown error' });
    }
  }

  // Fetch changes since cursor
  const cursor = req.cursor ? new Date(req.cursor) : null;
  const nextCursor = new Date().toISOString();

  const [updatedNotes, updatedFolders, updatedTasks, deletedNotes, deletedTasks] = await Promise.all([
    cursor
      ? db.query.notes.findMany({ where: and(eq(notes.userId, userId), gt(notes.updatedAt, cursor), isNotNull(notes.deletedAt) ? undefined : eq(notes.deletedAt, null as any)) })
      : db.query.notes.findMany({ where: and(eq(notes.userId, userId)) }),
    cursor
      ? db.query.folders.findMany({ where: and(eq(folders.userId, userId), gt(folders.updatedAt, cursor)) })
      : db.query.folders.findMany({ where: eq(folders.userId, userId) }),
    cursor
      ? db.query.tasks.findMany({ where: and(eq(tasks.userId, userId), gt(tasks.updatedAt, cursor)) })
      : db.query.tasks.findMany({ where: and(eq(tasks.userId, userId)) }),
    // Tombstones: soft-deleted items updated since cursor
    cursor
      ? db.query.notes.findMany({ where: and(eq(notes.userId, userId), gt(notes.updatedAt, cursor), isNotNull(notes.deletedAt)) })
      : [],
    cursor
      ? db.query.tasks.findMany({ where: and(eq(tasks.userId, userId), gt(tasks.updatedAt, cursor), isNotNull(tasks.deletedAt)) })
      : [],
  ]);

  const deleted: SyncTombstone[] = [
    ...deletedNotes.map(n => ({ entityType: 'note' as const, entityId: n.id, deletedAt: n.deletedAt!.toISOString() })),
    ...deletedTasks.map(t => ({ entityType: 'task' as const, entityId: t.id, deletedAt: t.deletedAt!.toISOString() })),
  ];

  // Filter out soft-deleted from live lists
  const liveNotes = updatedNotes.filter(n => !n.deletedAt);
  const liveTasks = updatedTasks.filter(t => !t.deletedAt);

  return {
    nextCursor,
    notes: liveNotes,
    folders: updatedFolders,
    tasks: liveTasks,
    deleted,
    processedOpIds,
    ...(errors.length > 0 ? { errors } : {}),
  };
}
