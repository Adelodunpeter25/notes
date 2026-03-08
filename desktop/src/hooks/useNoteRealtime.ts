import { useCallback, useEffect, useRef, useState } from "react";

import { authStorage } from "@/services/apiClient";
import { NoteSocket } from "@/services/ws/noteSocket";

export function useNoteRealtime(noteID?: string) {
  const [isReady, setIsReady] = useState(false);
  const socketRef = useRef<NoteSocket | null>(null);

  if (!socketRef.current) {
    socketRef.current = new NoteSocket();
  }

  useEffect(() => {
    const socket = socketRef.current;
    if (!socket) {
      setIsReady(false);
      return;
    }

    if (!noteID) {
      setIsReady(false);
      socket.close();
      return;
    }

    const token = authStorage.getToken();
    if (!token) {
      setIsReady(false);
      return;
    }

    let isMounted = true;
    const connectTimeout = setTimeout(() => {
      if (!isMounted) return;
      socket.connect(noteID, token, {
        onReady: () => setIsReady(true),
        onClose: () => setIsReady(false),
        onError: () => setIsReady(false),
      });
    }, 50);

    return () => {
      isMounted = false;
      clearTimeout(connectTimeout);
      socket.close();
      setIsReady(false);
    };
  }, [noteID]);

  const sendPatch = useCallback(
    (payload: { content: string; title?: string; isPinned?: boolean }, flush = false) => {
      const socket = socketRef.current;
      if (!socket) {
        return Promise.reject(new Error("socket not ready"));
      }
      return socket.sendPatch(payload, flush);
    },
    [],
  );

  const close = useCallback(() => {
    socketRef.current?.close();
  }, []);

  return {
    isReady,
    sendPatch,
    close,
  };
}
