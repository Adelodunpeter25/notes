import type { ButtonHTMLAttributes, PropsWithChildren } from "react";
import { Loader2 } from "lucide-react";
import { cn } from "@shared-utils/cn";

type ButtonVariant = "primary" | "secondary" | "ghost" | "destructive";

type ButtonProps = PropsWithChildren<
  ButtonHTMLAttributes<HTMLButtonElement> & {
    variant?: ButtonVariant;
    loading?: boolean;
  }
>;

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    "bg-[#c19b1f] text-white hover:bg-[#d4ac2b] focus:ring-accent/40 disabled:bg-[#c19b1f]/50",
  secondary:
    "bg-surface text-text hover:bg-surface/80 focus:ring-border disabled:opacity-60",
  ghost:
    "bg-transparent text-text hover:bg-surface/70 focus:ring-border disabled:opacity-60",
  destructive:
    "bg-danger text-white hover:bg-danger/80 focus:ring-danger/40 disabled:bg-danger/60",
};

export function Button({
  type = "button",
  variant = "primary",
  loading = false,
  className,
  children,
  disabled,
  ...props
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      className={cn(
        "inline-flex h-10 items-center justify-center rounded-xl px-4 text-sm font-bold tracking-tight",
        "transition-all duration-200 ease-apple focus:outline-none focus:ring-2",
        "disabled:cursor-not-allowed",
        variantStyles[variant],
        className
      )}
      {...props}
    >
      {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
      {children}
    </button>
  );
}
