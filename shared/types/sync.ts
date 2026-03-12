import type { Folder } from "./folders";
import type { Note } from "./notes";
import type { Task } from "./tasks";

export type SyncOperation = {
  type: "upsert" | "delete";
  entityType: "note" | "folder" | "task";
  entityId: string;
  payload?: any;
};

export type SyncRequest = {
  lastSyncAt?: string;
  lastCursor?: string;
  ops: SyncOperation[];
};

export type SyncResponse = {
  serverTime: string;
  nextCursor: string;
  notes: Note[];
  folders: Folder[];
  tasks: Task[];
  deleted: { entityType: "note" | "folder" | "task"; entityId: string }[];
  processedOpIds: string[];
  idMappings: { localId: string; serverId: string }[];
};
