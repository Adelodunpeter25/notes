type SkeletonProps = {
  className?: string;
};

export function Skeleton({ className }: SkeletonProps) {
  return (
    <div
      className={[
        "animate-pulse rounded-lg bg-surface/70",
        className || "h-4 w-full",
      ]
        .filter(Boolean)
        .join(" ")}
    />
  );
}
