import { API_BASE_URL } from "@/api/apiClient";
import type { NotePatchMessage, NoteSocketServerMessage } from "@shared/ws";
import { getReconnectDelay } from "../../../../shared/utils/reconnect";

type PendingRequest = {
  resolve: () => void;
  reject: (error: Error) => void;
  timeout: ReturnType<typeof setTimeout>;
};

type NoteSocketHandlers = {
  onReady?: () => void;
  onClose?: () => void;
  onError?: (error: Error) => void;
};

function buildNoteSocketURL(noteId: string, token: string): string {
  const wsBase = API_BASE_URL
    .replace(/^http:\/\//i, "ws://")
    .replace(/^https:\/\//i, "wss://");

  return `${wsBase}/ws/notes/${encodeURIComponent(noteId)}?token=${encodeURIComponent(token)}`;
}

export class NoteSocket {
  private socket: WebSocket | null = null;
  private noteID: string | null = null;
  private token: string | null = null;
  private shouldReconnect = false;
  private reconnectAttempt = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private requestCounter = 0;
  private pendingRequests = new Map<string, PendingRequest>();
  private handlers: NoteSocketHandlers = {};

  connect(noteId: string, token: string, handlers?: NoteSocketHandlers) {
    this.handlers = handlers ?? {};
    this.noteID = noteId;
    this.token = token;
    this.shouldReconnect = true;
    this.openSocket();
  }

  private openSocket() {
    if (!this.noteID || !this.token) {
      return;
    }
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    this.socket = new WebSocket(buildNoteSocketURL(this.noteID, this.token));
    this.socket.onopen = () => {
      this.reconnectAttempt = 0;
      this.handlers.onReady?.();
    };

    this.socket.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data as string) as NoteSocketServerMessage;
        if (message.type === "ack") {
          const pending = this.pendingRequests.get(message.requestId);
          if (pending) {
            clearTimeout(pending.timeout);
            this.pendingRequests.delete(message.requestId);
            pending.resolve();
          }
          return;
        }

        if (message.type === "error" && message.requestId) {
          const pending = this.pendingRequests.get(message.requestId);
          if (pending) {
            clearTimeout(pending.timeout);
            this.pendingRequests.delete(message.requestId);
            pending.reject(new Error(message.message));
          }
        }
      } catch (error) {
        this.handlers.onError?.(error as Error);
      }
    };

    this.socket.onerror = () => {
      this.handlers.onError?.(new Error("websocket error"));
    };

    this.socket.onclose = () => {
      this.rejectAllPending(new Error("websocket closed"));
      this.handlers.onClose?.();
      if (this.shouldReconnect) {
        this.scheduleReconnect();
      }
    };
  }

  private scheduleReconnect() {
    const delay = getReconnectDelay(this.reconnectAttempt++);
    this.reconnectTimer = setTimeout(() => {
      this.openSocket();
    }, delay);
  }

  get isReady(): boolean {
    return this.socket?.readyState === WebSocket.OPEN;
  }

  async sendPatch(payload: { content: string; title?: string; isPinned?: boolean }, flush = false): Promise<void> {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      throw new Error("socket not ready");
    }

    const requestId = `${Date.now()}-${++this.requestCounter}`;
    const message: NotePatchMessage = {
      type: "patch",
      requestId,
      content: payload.content,
      ...(payload.title !== undefined ? { title: payload.title } : {}),
      ...(payload.isPinned !== undefined ? { isPinned: payload.isPinned } : {}),
      ...(flush ? { flush: true } : {}),
    };

    return new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(requestId);
        reject(new Error("socket ack timeout"));
      }, flush ? 7000 : 5000);

      this.pendingRequests.set(requestId, { resolve, reject, timeout });
      this.socket?.send(JSON.stringify(message));
    });
  }

  close() {
    this.shouldReconnect = false;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.rejectAllPending(new Error("socket closed"));
    this.socket?.close();
    this.socket = null;
  }

  private rejectAllPending(error: Error) {
    for (const [requestId, pending] of this.pendingRequests) {
      clearTimeout(pending.timeout);
      pending.reject(error);
      this.pendingRequests.delete(requestId);
    }
  }
}
