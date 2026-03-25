export type SyncOpType = 'upsert' | 'delete';
export type SyncEntityType = 'note' | 'folder' | 'task';

export type SyncOperation = {
  id: string;
  type: SyncOpType;
  entityType: SyncEntityType;
  entityId: string;
  updatedAt: string;
  payload?: Record<string, unknown>;
};

export type SyncRequest = {
  cursor: string | null;
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
  errors?: { opId: string; error: string }[];
};
