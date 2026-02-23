import type { PropsWithChildren, ReactNode } from "react";

type SidebarItemProps = PropsWithChildren<{
  icon?: ReactNode;
  active?: boolean;
  count?: number;
  variant?: "folder" | "note";
  onClick?: () => void;
  onDoubleClick?: () => void;
  isEditing?: boolean;
  editValue?: string;
  onEditChange?: (value: string) => void;
  onEditSubmit?: () => void;
  onEditCancel?: () => void;
}>;

export function SidebarItem({
  icon,
  active = false,
  count,
  variant = "folder",
  onClick,
  onDoubleClick,
  children,
  isEditing,
  editValue,
  onEditChange,
  onEditSubmit,
  onEditCancel,
}: SidebarItemProps) {
  const isFolder = variant === "folder";

  return (
    <button
      type="button"
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      className={[
        "flex min-h-[30px] w-full items-center gap-2.5 rounded-md px-2 py-1 text-left text-[14px]",
        "transition-colors duration-150 ease-in-out group",
        active
          ? isFolder
            ? "bg-[#c19b1f] text-white"
            : "bg-[#333333] text-text"
          : isFolder
            ? "border border-transparent text-[#e3e3e3] hover:bg-white/5"
            : "text-text hover:bg-white/5",
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {icon ? (
        <span className={["flex items-center justify-center shrink-0", active && isFolder ? "text-white" : isFolder ? "text-accent" : "currentColor"].join(" ")}>
          {icon}
        </span>
      ) : null}

      {isEditing ? (
        <div className="flex-1 overflow-hidden" onClick={e => e.stopPropagation()}>
          <input
            autoFocus
            value={editValue}
            onChange={(e) => onEditChange?.(e.target.value)}
            onBlur={onEditSubmit}
            onKeyDown={(e) => {
              if (e.key === "Enter") onEditSubmit?.();
              if (e.key === "Escape") onEditCancel?.();
            }}
            className="w-full bg-black/20 text-white px-1.5 py-0.5 rounded border border-accent outline-none text-[13px]"
          />
        </div>
      ) : (
        <span className="flex-1 truncate font-medium tracking-wide">{children}</span>
      )}

      {typeof count === "number" && !isEditing ? <span className={["text-[13px] font-medium pr-1", active && isFolder ? "text-white" : "text-[#7a7a7a]"].join(" ")}>{count}</span> : null}
    </button>
  );
}
