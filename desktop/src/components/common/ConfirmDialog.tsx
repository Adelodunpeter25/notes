import { useEffect, useRef } from "react";
import { ask } from "@tauri-apps/plugin-dialog";

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
  const isDialogOpen = useRef(false);

  useEffect(() => {
    if (open && !isDialogOpen.current) {
      isDialogOpen.current = true;
      const showDialog = async () => {
        try {
          const result = await ask(description || "", {
            title: title,
            kind: destructive ? "warning" : "info",
            okLabel: confirmLabel,
            cancelLabel: cancelLabel,
          });

          if (result) {
            onConfirm();
          } else {
            onCancel();
          }
        } catch (error) {
          console.error("Native dialog error:", error);
          onCancel();
        } finally {
          isDialogOpen.current = false;
        }
      };
      void showDialog();
    }
  }, [open, title, description, confirmLabel, cancelLabel, onConfirm, onCancel, destructive]);

  return null;
}
