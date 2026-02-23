import type { InputHTMLAttributes } from "react";

type InputProps = InputHTMLAttributes<HTMLInputElement>;

export function Input({ className, ...props }: InputProps) {
  return (
    <input
      className={[
        "h-11 w-full rounded-xl border border-border bg-background/70 px-4 text-sm text-text outline-none",
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
