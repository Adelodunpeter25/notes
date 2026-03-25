import React from "react";
import { TouchableOpacity, Text, ActivityIndicator, View } from "react-native";
import { cn } from "@shared-utils/cn";

interface ButtonProps {
    onPress: () => void;
    title: string;
    variant?: "primary" | "outline" | "ghost" | "danger";
    size?: "sm" | "md" | "lg";
    loading?: boolean;
    disabled?: boolean;
    className?: string;
    textClassName?: string;
    icon?: React.ReactNode;
}

export function Button({
    onPress,
    title,
    variant = "primary",
    size = "md",
    loading = false,
    disabled = false,
    className,
    textClassName,
    icon,
}: ButtonProps) {
    const variants = {
        primary: "bg-accent",
        outline: "border border-border bg-transparent",
        ghost: "bg-transparent",
        danger: "bg-red-500",
    };

    const sizes = {
        sm: "px-3 py-1.5 rounded-md",
        md: "px-4 py-2.5 rounded-lg",
        lg: "px-6 py-3.5 rounded-xl",
    };

    const textColors = {
        primary: "text-black",
        outline: "text-text",
        ghost: "text-textMuted",
        danger: "text-white",
    };

    return (
        <TouchableOpacity
            onPress={onPress}
            disabled={disabled || loading}
            activeOpacity={0.7}
            className={cn(
                "flex-row items-center justify-center",
                sizes[size],
                variants[variant],
                (disabled || loading) && "opacity-50",
                className
            )}
        >
            {loading ? (
                <ActivityIndicator color={variant === "primary" ? "#000" : "#fff"} size="small" />
            ) : (
                <View className="flex-row items-center">
                    {icon && <View className="mr-2">{icon}</View>}
                    <Text
                        className={cn(
                            "text-[15px] font-semibold text-center",
                            textColors[variant],
                            textClassName
                        )}
                    >
                        {title}
                    </Text>
                </View>
            )}
        </TouchableOpacity>
    );
}
