import React from "react";
import { TouchableOpacity, Text, View, type GestureResponderEvent } from "react-native";
import { ChevronRight } from "lucide-react-native";
import { cn } from "@/utils/cn";

interface ListItemProps {
    title: string;
    subtitle?: React.ReactNode;
    titleClassName?: string;
    subtitleClassName?: string;
    icon?: React.ReactNode;
    count?: number;
    onPress: () => void;
    onLongPress?: (event: GestureResponderEvent) => void;
    className?: string;
    showChevron?: boolean;
    isActive?: boolean;
}

export function ListItem({
    title,
    subtitle,
    titleClassName,
    subtitleClassName,
    icon,
    count,
    onPress,
    onLongPress,
    className,
    showChevron = true,
    isActive = false,
}: ListItemProps) {
    return (
        <TouchableOpacity
            onPress={onPress}
            onLongPress={onLongPress}
            delayLongPress={220}
            activeOpacity={0.6}
            className={cn(
                "flex-row items-center justify-between py-3.5 px-4 border-b border-border/50",
                isActive && "bg-surfaceSecondary",
                className
            )}
        >
            <View className="flex-row items-center flex-1">
                {icon && <View className="mr-3">{icon}</View>}
                <View className="flex-1">
                    <Text className={cn("text-[17px] font-medium text-text", titleClassName)} numberOfLines={1}>{title}</Text>
                    {subtitle && (
                        typeof subtitle === "string" ? (
                            <Text className={cn("text-[14px] text-textMuted mt-0.5", subtitleClassName)} numberOfLines={1}>
                                {subtitle}
                            </Text>
                        ) : (
                            <View className="mt-0.5">{subtitle}</View>
                        )
                    )}
                </View>
            </View>

            <View className="flex-row items-center">
                {count !== undefined && (
                    <Text className="text-[16px] text-textMuted mr-2">{count}</Text>
                )}
                {showChevron && <ChevronRight size={18} color="#a0a0a0" />}
            </View>
        </TouchableOpacity>
    );
}
