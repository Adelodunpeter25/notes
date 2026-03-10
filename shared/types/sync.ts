import type { Folder } from "./folders";
import type { Note, UpdateNotePayload } from "./notes";
import type { Task, UpdateTaskPayload } from "./tasks";

export type SyncOperation = {
  type: "upsert" | "delete";
  entityType: "note" | "folder" | "task";
  entityId: string;
  payload?: any;
};

export type SyncRequest = {
  lastSyncAt?: string;
  ops: SyncOperation[];
};

export type SyncResponse = {
  serverTime: string;
  notes: Note[];
  folders: Folder[];
  tasks: Task[];
  processedOpIds: string[];
  idMappings: { localId: string; serverId: string }[];
};
