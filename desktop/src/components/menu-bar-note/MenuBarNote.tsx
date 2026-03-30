import { useEffect, useRef, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";

export function MenuBarNote() {
  const [content, setContent] = useState("");
  const contentRef = useRef("");
  const saveTimerRef = useRef<ReturnType<typeof setTimeout>>();
  const initializedRef = useRef(false);

  async function load() {
    if (initializedRef.current) return;
    initializedRef.current = true;
    try {
      const text = await invoke<string>("get_scratch_pad");
      setContent(text);
      contentRef.current = text;
    } catch {
      setContent("");
      contentRef.current = "";
    }
  }

  async function save() {
    if (!contentRef.current.trim()) return;
    try {
      await invoke("save_scratch_pad", { content: contentRef.current });
    } catch {}
  }

  function handleChange(val: string) {
    contentRef.current = val;
    setContent(val);
    clearTimeout(saveTimerRef.current);
    saveTimerRef.current = setTimeout(save, 500);
  }

  async function saveAndHide() {
    clearTimeout(saveTimerRef.current);
    await save();
    getCurrentWindow().hide();
  }

  useEffect(() => {
    let unlistenFocus: (() => void) | undefined;

    getCurrentWindow().onFocusChanged(({ payload: focused }) => {
      if (focused) {
        load();
      } else {
        saveAndHide();
      }
    }).then((fn) => { unlistenFocus = fn; });

    getCurrentWindow().isVisible().then((visible) => {
      if (visible) load();
    });

    return () => {
      unlistenFocus?.();
      clearTimeout(saveTimerRef.current);
    };
  }, []);

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        saveAndHide();
      }
    }
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  return (
    <div className="flex h-full flex-col bg-surface rounded-xl shadow-2xl ring-1 ring-white/10 overflow-hidden">
      <div
        data-tauri-drag-region
        className="h-7 shrink-0 cursor-grab bg-surface rounded-t-xl flex items-center px-3 select-none border-b border-border"
      >
        <span className="text-[10px] text-muted font-medium pointer-events-none">
          Scratch Pad
        </span>
      </div>
      <textarea
        value={content}
        onChange={(e) => handleChange(e.target.value)}
        placeholder="Quick capture..."
        autoFocus
        className="flex-1 bg-transparent text-text text-sm p-3 resize-none outline-none placeholder:text-muted/40 scrollbar-none"
      />
    </div>
  );
}
