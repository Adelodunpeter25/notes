import type { ButtonHTMLAttributes, PropsWithChildren } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost" | "destructive";

type ButtonProps = PropsWithChildren<
  ButtonHTMLAttributes<HTMLButtonElement> & {
    variant?: ButtonVariant;
  }
>;

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    "bg-accent text-accent-foreground hover:bg-accent-soft focus:ring-accent/40 disabled:bg-accent/50",
  secondary:
    "bg-surface text-text hover:bg-surface/80 focus:ring-border disabled:opacity-60",
  ghost:
    "bg-transparent text-text hover:bg-surface/70 focus:ring-border disabled:opacity-60",
  destructive:
    "bg-danger text-danger-foreground hover:bg-danger-soft focus:ring-danger/40 disabled:bg-danger/60",
};

export function Button({
  type = "button",
  variant = "primary",
  className,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      type={type}
      className={[
        "inline-flex h-10 items-center justify-center rounded-xl px-4 text-sm font-medium",
        "transition-all duration-200 ease-apple focus:outline-none focus:ring-2",
        "disabled:cursor-not-allowed",
        variantStyles[variant],
        className,
      ]
        .filter(Boolean)
        .join(" ")}
      {...props}
    >
      {children}
    </button>
  );
}
