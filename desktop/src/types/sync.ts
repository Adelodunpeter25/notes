import type { Folder } from "./folders";
import type { Note } from "./notes";

export type SyncOperation = {
  type: "upsert" | "delete";
  entityType: "note" | "folder";
  entityId: string;
  payload?: any;
};

export type SyncRequest = {
  lastSyncAt?: string;
  lastCursor?: string;
  deviceId?: string;
  ops: SyncOperation[];
};

export type SyncResponse = {
  serverTime: string;
  nextCursor: string;
  notes: Note[];
  folders: Folder[];
  deleted: { entityType: "note" | "folder"; entityId: string }[];
  processedOpIds: string[];
  idMappings: { localId: string; serverId: string }[];
};
