import { AppleNotesIcon } from "./AppleNotesIcon";

type ConfirmDialogProps = {
  open: boolean;
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm: () => void;
  onCancel: () => void;
  loading?: boolean;
  destructive?: boolean;
};

export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  onConfirm,
  onCancel,
  loading = false,
  destructive = false,
}: ConfirmDialogProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 backdrop-blur-[2px] transition-opacity">
      <div
        className="w-full max-w-[260px] rounded-[14px] bg-[#3B3B3D] p-4 shadow-2xl flex flex-col items-center border border-white/10"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3">
          <AppleNotesIcon />
        </div>

        <h2 className="mb-2 text-center text-[15px] font-bold leading-snug text-white px-2">
          {title}
        </h2>
        {description && (
          <p className="mb-5 text-center text-[13px] font-medium text-[#d0d0d0] px-2 leading-tight">
            {description}
          </p>
        )}

        <div className="flex w-full gap-2.5">
          <button
            onClick={onCancel}
            disabled={loading}
            className="flex-1 rounded-[8px] bg-[#656566] py-[6px] text-[14px] font-medium text-white transition-colors hover:bg-[#727273]"
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className={`flex-1 rounded-[8px] py-[6px] text-[14px] font-medium transition-colors ${destructive
              ? "bg-[#D9A51C] text-[#221A04] hover:bg-[#e4ad1e]"
              : "bg-accent text-accent-foreground hover:bg-accent/90"
              }`}
          >
            {loading ? "..." : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
