export type NotePatchMessage = {
  type: "patch";
  requestId: string;
  content: string;
  title?: string;
  isPinned?: boolean;
  flush?: boolean;
};

export type NoteAckMessage = {
  type: "ack";
  requestId: string;
  savedAt: string;
};

export type NoteErrorMessage = {
  type: "error";
  requestId?: string;
  message: string;
};

export type NoteSocketServerMessage = NoteAckMessage | NoteErrorMessage | NotePatchMessage;

