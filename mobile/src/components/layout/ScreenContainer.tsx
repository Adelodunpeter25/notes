import React from "react";
import { View, type ViewProps } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { cn } from "@/utils/cn";

interface ScreenContainerProps extends ViewProps {
    children: React.ReactNode;
    useSafeArea?: boolean;
    edges?: ("top" | "bottom" | "left" | "right")[];
}

export function ScreenContainer({
    children,
    useSafeArea = true,
    edges = ["top", "bottom", "left", "right"],
    className,
    style,
    ...props
}: ScreenContainerProps) {
    const insets = useSafeAreaInsets();

    const safeStyle = useSafeArea ? {
        paddingTop: edges.includes("top") ? insets.top : 0,
        paddingBottom: edges.includes("bottom") ? insets.bottom : 0,
        paddingLeft: edges.includes("left") ? insets.left : 0,
        paddingRight: edges.includes("right") ? insets.right : 0,
    } : {};

    return (
        <View
            className={cn("flex-1 bg-background", className)}
            style={[safeStyle, style]}
            {...props}
        >
            {children}
        </View>
    );
}
