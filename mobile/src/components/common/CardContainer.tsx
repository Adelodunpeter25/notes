import React from "react";
import { View, type ViewProps } from "react-native";
import { cn } from "@shared-utils/cn";

type CardContainerProps = ViewProps & {
  className?: string;
};

export function CardContainer({ className, ...props }: CardContainerProps) {
  return (
    <View
      {...props}
      className={cn(
        "mx-4 mt-3 overflow-hidden rounded-2xl border border-border/50 bg-surfaceSecondary",
        className,
      )}
    />
  );
}

