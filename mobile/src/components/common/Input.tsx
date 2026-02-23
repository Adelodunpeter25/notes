import React from "react";
import { TextInput, View, Text, type TextInputProps } from "react-native";
import { cn } from "@/utils/cn";

interface InputProps extends TextInputProps {
    label?: string;
    error?: string;
    containerClassName?: string;
}

export function Input({
    label,
    error,
    containerClassName,
    className,
    ...props
}: InputProps) {
    return (
        <View className={cn("w-full mb-4", containerClassName)}>
            {label && (
                <Text className="text-[14px] font-medium text-textMuted mb-2 px-1">
                    {label}
                </Text>
            )}
            <TextInput
                placeholderTextColor="#636366"
                className={cn(
                    "bg-surface border border-border px-4 py-3 rounded-xl text-text text-[16px] transition-colors focus:border-accent",
                    error && "border-red-500",
                    className
                )}
                {...props}
            />
            {error && (
                <Text className="text-red-500 text-[12px] mt-1 px-1">{error}</Text>
            )}
        </View>
    );
}
