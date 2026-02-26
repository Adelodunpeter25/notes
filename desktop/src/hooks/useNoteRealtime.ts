import { useCallback, useEffect, useMemo, useState } from "react";

import { authStorage } from "@/services/apiClient";
import { NoteSocket } from "@/services/ws/noteSocket";

export function useNoteRealtime(noteID?: string) {
  const [isReady, setIsReady] = useState(false);
  const socket = useMemo(() => new NoteSocket(), [noteID]);

  useEffect(() => {
    if (!noteID) {
      setIsReady(false);
      return;
    }

    const token = authStorage.getToken();
    if (!token) {
      setIsReady(false);
      return;
    }

    socket.connect(noteID, token, {
      onReady: () => setIsReady(true),
      onClose: () => setIsReady(false),
      onError: () => setIsReady(false),
    });

    return () => {
      socket.close();
      setIsReady(false);
    };
  }, [noteID, socket]);

  const sendPatch = useCallback(
    (payload: { content: string; title?: string; isPinned?: boolean }, flush = false) =>
      socket.sendPatch(payload, flush),
    [socket],
  );

  const close = useCallback(() => {
    socket.close();
  }, [socket]);

  return {
    isReady,
    sendPatch,
    close,
  };
}
