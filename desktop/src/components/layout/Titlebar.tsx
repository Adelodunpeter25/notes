import type { MouseEvent } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { useUiStore } from "@/stores";
import { cn } from "@/utils/cn";

const isDesktop =
  typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

export function Titlebar() {
  const activeView = useUiStore((state) => state.activeView);
  const setActiveView = useUiStore((state) => state.setActiveView);

  async function handleStartDrag(event: MouseEvent<HTMLElement>) {
    if (!isDesktop || event.button !== 0) {
      return;
    }

    const target = event.target as HTMLElement | null;
    if (target?.closest("[data-no-drag='true']")) {
      return;
    }

    try {
      await getCurrentWindow().startDragging();
    } catch {
      return;
    }
  }

  return (
    <header
      data-tauri-drag-region
      onMouseDown={handleStartDrag}
      className="drag-region flex h-[32px] select-none items-center justify-center border-b border-border bg-[#2b2b2b] px-4"
    >
      <div className="flex h-full items-center gap-1" data-no-drag="true">
        <button
          onClick={() => setActiveView("notes")}
          className={cn(
            "flex h-full items-center px-4 text-[12px] font-medium transition-colors",
            activeView === "notes"
              ? "bg-white/5 text-text border-b-2 border-accent"
              : "text-muted hover:text-text hover:bg-white/5"
          )}
        >
          Notes
        </button>
        <button
          onClick={() => setActiveView("tasks")}
          className={cn(
            "flex h-full items-center px-4 text-[12px] font-medium transition-colors",
            activeView === "tasks"
              ? "bg-white/5 text-text border-b-2 border-accent"
              : "text-muted hover:text-text hover:bg-white/5"
          )}
        >
          Tasks
        </button>
      </div>
    </header>
  );
}
