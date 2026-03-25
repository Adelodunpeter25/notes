import type { PropsWithChildren, ReactNode } from "react";

import { Button } from "./Button";

type ModalProps = PropsWithChildren<{
  open: boolean;
  title: string;
  description?: string;
  onClose: () => void;
  footer?: ReactNode;
}>;

export function Modal({ open, title, description, onClose, footer, children }: ModalProps) {
  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <button
        type="button"
        aria-label="Close modal"
        className="absolute inset-0 bg-black/60 backdrop-blur-[1px]"
        onClick={onClose}
      />

      <section className="relative z-10 w-full max-w-md rounded-2xl border border-border bg-surface p-5 shadow-card">
        <header className="mb-4 space-y-1">
          <h2 className="text-lg font-semibold text-text">{title}</h2>
          {description ? <p className="text-sm text-muted">{description}</p> : null}
        </header>

        <div className="space-y-3">{children}</div>

        <footer className="mt-5 flex items-center justify-end gap-2">
          {footer ?? <Button variant="secondary" onClick={onClose}>Close</Button>}
        </footer>
      </section>
    </div>
  );
}
