import { useCallback, useEffect, useMemo, useState } from "react";

import { NoteSocket } from "@/services/ws/noteSocket";

type UseNoteRealtimeParams = {
  noteId: string;
  token: string | null;
};

function isServerNoteID(noteId: string): boolean {
  return Boolean(noteId) && !noteId.startsWith("local_");
}

export function useNoteRealtime({ noteId, token }: UseNoteRealtimeParams) {
  const [isReady, setIsReady] = useState(false);

  const socket = useMemo(() => new NoteSocket(), [noteId]);

  useEffect(() => {
    if (!token || !noteId || !isServerNoteID(noteId)) {
      socket.close();
      setIsReady(false);
      return;
    }

    socket.connect(noteId, token, {
      onReady: () => setIsReady(true),
      onClose: () => setIsReady(false),
      onError: () => setIsReady(false),
    });

    return () => {
      socket.close();
      setIsReady(false);
    };
  }, [socket, noteId, token]);

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
