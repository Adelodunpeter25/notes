import { type MouseEvent } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { RefreshCw } from "lucide-react";
import { useUiStore } from "@/stores";
import { cn } from "@/utils/cn";

const isDesktop =
  typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

type TitlebarProps = {
  syncNow?: () => Promise<void> | void;
  isSyncing?: boolean;
};

export function Titlebar({ syncNow, isSyncing = false }: TitlebarProps) {
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
      className="drag-region flex h-[36px] select-none items-center justify-between border-b border-border bg-[#2c2c2c] px-4"
    >
      {/* Platform Controls Spacer (macOS traffic lights) */}
      <div className="w-[80px]" />

      <div className="flex items-center gap-2" data-no-drag="true">
        <button
          onClick={() => setActiveView("notes")}
          className={cn(
            "flex h-7 items-center rounded-full border px-4 text-[12px] font-bold tracking-tight transition-all",
            activeView === "notes"
              ? "bg-white/10 text-text border-[#c19b1f]"
              : "text-muted border-border/60 hover:text-text hover:border-border"
          )}
        >
          Notes
        </button>
        <button
          onClick={() => setActiveView("tasks")}
          className={cn(
            "flex h-7 items-center rounded-full border px-4 text-[12px] font-bold tracking-tight transition-all",
            activeView === "tasks"
              ? "bg-white/10 text-text border-[#c19b1f]"
              : "text-muted border-border/60 hover:text-text hover:border-border"
          )}
        >
          Tasks
        </button>
      </div>

      <div className="flex items-center" data-no-drag="true">
        <button
          onClick={() => syncNow?.()}
          disabled={isSyncing}
          className={cn(
            "flex size-7 items-center justify-center rounded-md text-muted transition-all hover:bg-white/10 hover:text-text",
            isSyncing && "animate-spin text-accent"
          )}
          title="Sync Now"
        >
          <RefreshCw size={14} />
        </button>
      </div>
    </header>
  );
}
