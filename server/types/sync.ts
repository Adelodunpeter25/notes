export type SyncOpType = 'upsert' | 'delete';
export type SyncEntityType = 'note' | 'folder' | 'task';

export type SyncOperation = {
  id: string;           // client-generated op id for idempotency
  type: SyncOpType;
  entityType: SyncEntityType;
  entityId: string;     // real UUID (device generates UUIDs, no local_ prefix needed)
  updatedAt: string;    // ISO string — used for conflict resolution
  payload?: Record<string, unknown>;
};

export type SyncRequest = {
  cursor: string | null; // ISO timestamp of last sync, null for first sync
  ops: SyncOperation[];
};

export type SyncTombstone = {
  entityType: SyncEntityType;
  entityId: string;
  deletedAt: string;
};

export type SyncResponse = {
  nextCursor: string;
  notes: unknown[];
  folders: unknown[];
  tasks: unknown[];
  deleted: SyncTombstone[];
  processedOpIds: string[];
};
