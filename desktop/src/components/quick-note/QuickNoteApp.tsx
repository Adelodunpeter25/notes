import { useEffect, useRef, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";

import { Editor } from "@/components/editor";
import { deriveNoteTitleFromHtml } from "@shared-utils/noteContent";
import type { Note } from "@shared/notes";

export function QuickNoteApp() {
  const [note, setNote] = useState<Note | null>(null);
  const [content, setContent] = useState("");
  const contentRef = useRef("");
  const noteRef = useRef<Note | null>(null);
  const initializedRef = useRef(false);

  async function init() {
    if (initializedRef.current) return;
    initializedRef.current = true;

    const params = new URLSearchParams(window.location.search);
    const noteId = params.get("noteId");

    if (noteId) {
      const existing = await invoke<Note>("get_note", { id: noteId });
      setNote(existing);
      setContent(existing.content);
      contentRef.current = existing.content;
      noteRef.current = existing;
    } else {
      const created = await invoke<Note>("create_note", {
        payload: { title: "Quick Note", content: "" },
      });
      setNote(created);
      setContent("");
      contentRef.current = "";
      noteRef.current = created;
    }
  }

  // Only init when the window becomes visible (not on hidden startup)
  useEffect(() => {
    let unlistenFocus: (() => void) | undefined;

    getCurrentWindow().onFocusChanged(({ payload: focused }) => {
      if (focused) void init();
    }).then((fn) => { unlistenFocus = fn; });

    getCurrentWindow().isVisible().then((visible) => {
      if (visible) void init();
    });

    // Restore saved size (v2 = logical pixels)
    const saved = localStorage.getItem("quick-note-size-v2");
    if (saved) {
      try {
        const { width, height } = JSON.parse(saved);
        getCurrentWindow().setSize({ type: "Logical", width, height });
      } catch {}
    }

    // Save size on resize using outerSize (logical pixels)
    let resizeTimer: ReturnType<typeof setTimeout>;
    const onResize = () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(async () => {
        const size = await getCurrentWindow().outerSize();
        const factor = await getCurrentWindow().scaleFactor();
        localStorage.setItem("quick-note-size-v2", JSON.stringify({
          width: Math.round(size.width / factor),
          height: Math.round(size.height / factor),
        }));
      }, 300);
    };
    window.addEventListener("resize", onResize);

    return () => { unlistenFocus?.(); window.removeEventListener("resize", onResize); };
  }, []);

  // Escape to close (saves if not empty)
  useEffect(() => {
    async function handleKeyDown(e: KeyboardEvent) {
      if (e.key !== "Escape") return;
      const current = noteRef.current;
      if (current && contentRef.current.trim() && contentRef.current !== "<p></p>") {
        const title = deriveNoteTitleFromHtml(contentRef.current) || "Quick Note";
        await invoke("update_note", { id: current.id, payload: { title, content: contentRef.current } });
      }
      getCurrentWindow().hide();
    }
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);
  useEffect(() => {
    let unlisten: (() => void) | undefined;

    getCurrentWindow().onCloseRequested(async (event) => {
      event.preventDefault();
      const current = noteRef.current;
      if (current) {
        const title = deriveNoteTitleFromHtml(contentRef.current) || "Quick Note";
        await invoke("update_note", {
          id: current.id,
          payload: { title, content: contentRef.current },
        });
      }
      getCurrentWindow().destroy();
    }).then((fn) => { unlisten = fn; });

    return () => { unlisten?.(); };
  }, []);

  // 200ms debounce auto-save
  useEffect(() => {
    if (!note) return;
    const timer = setTimeout(async () => {
      const title = deriveNoteTitleFromHtml(contentRef.current) || "Quick Note";
      await invoke("update_note", {
        id: note.id,
        payload: { title, content: contentRef.current },
      });
    }, 200);
    return () => clearTimeout(timer);
  }, [content, note]);

  return (
    <div className="flex h-screen flex-col overflow-hidden rounded-xl bg-background text-text shadow-2xl ring-1 ring-white/10">
      <div
        data-tauri-drag-region
        className="h-8 shrink-0 cursor-grab bg-surface rounded-t-xl flex items-center px-3 select-none border-b border-border"
      >
        <span className="text-[11px] text-muted font-medium pointer-events-none">
          {note?.title && note.title !== "Quick Note" ? note.title : "Quick Note"}
        </span>
      </div>

      <div className="flex-1 overflow-y-auto scrollbar-none px-4 py-3 min-h-0">
        {note && (
          <Editor
            content={content}
            onChange={(val) => {
              contentRef.current = val;
              setContent(val);
            }}
          />
        )}
      </div>
    </div>
  );
}
