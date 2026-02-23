import type { MouseEvent } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";

type TitlebarProps = {
  title?: string;
};

const isDesktop =
  typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

export function Titlebar({ title = "Notes" }: TitlebarProps) {
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
      className="drag-region flex h-[28px] select-none items-center justify-center border-b border-border bg-[#2b2b2b]"
    >
      <p className="truncate text-[13px] font-medium text-[#b5b5b5] pointer-events-none">{title}</p>
    </header>
  );
}
