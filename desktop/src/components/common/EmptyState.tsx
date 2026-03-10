import type { ReactNode } from "react";
import { cn } from "@/utils/cn";

type EmptyStateProps = {
  icon?: ReactNode;
  title: string;
  description?: string;
  prompt?: string;
  action?: ReactNode;
  variant?: "boxed" | "simple";
};

export function EmptyState({ 
  icon, 
  title, 
  description, 
  prompt, 
  action,
  variant = "boxed"
}: EmptyStateProps) {
  const isBoxed = variant === "boxed";

  return (
    <div className={cn(
      "flex flex-col items-center justify-center gap-3 text-center",
      isBoxed 
        ? "min-h-52 rounded-xl border border-dashed border-border bg-surface/40 p-6" 
        : "py-12 px-4"
    )}>
      {icon ? (
        <div className="flex size-10 items-center justify-center rounded-full border border-border bg-background/70 text-accent">
          {icon}
        </div>
      ) : null}
      {prompt ? <p className="text-xs font-medium uppercase tracking-wide text-accent">{prompt}</p> : null}
      <h3 className="text-base font-semibold text-text">{title}</h3>
      {description ? <p className="max-w-md text-sm text-muted">{description}</p> : null}
      {action ? <div className="pt-1">{action}</div> : null}
    </div>
  );
}
