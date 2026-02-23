import React from "react";
import { TouchableOpacity, Text, View } from "react-native";
import { ChevronRight } from "lucide-react-native";
import { cn } from "@/utils/cn";

interface ListItemProps {
    title: string;
    subtitle?: React.ReactNode;
    icon?: React.ReactNode;
    count?: number;
    onPress: () => void;
    className?: string;
    showChevron?: boolean;
    isActive?: boolean;
}

export function ListItem({
    title,
    subtitle,
    icon,
    count,
    onPress,
    className,
    showChevron = true,
    isActive = false,
}: ListItemProps) {
    return (
        <TouchableOpacity
            onPress={onPress}
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
                    <Text className="text-[17px] font-medium text-text" numberOfLines={1}>{title}</Text>
                    {subtitle && (
                        typeof subtitle === "string" ? (
                            <Text className="text-[14px] text-textMuted mt-0.5" numberOfLines={1}>
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
