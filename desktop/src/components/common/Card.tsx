import type { PropsWithChildren } from "react";

type CardProps = PropsWithChildren<{
  className?: string;
}>;

export function Card({ className, children }: CardProps) {
  return (
    <section
      className={[
        "rounded-xl border border-border bg-surface/90 p-5 shadow-card backdrop-blur-sm",
        "transition-all duration-200 ease-apple",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {children}
    </section>
  );
}
