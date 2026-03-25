import type { TextareaHTMLAttributes } from "react";

type TextareaProps = TextareaHTMLAttributes<HTMLTextAreaElement>;

export function Textarea({ className, ...props }: TextareaProps) {
  return (
    <textarea
      className={[
        "min-h-32 w-full rounded-xl border border-border bg-background/70 px-4 py-3 text-sm text-text outline-none",
        "placeholder:text-muted focus:border-accent focus:ring-2 focus:ring-accent/30",
        "transition-all duration-200 ease-apple",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
      {...props}
    />
  );
}
