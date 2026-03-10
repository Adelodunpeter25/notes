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
    searchQuery?: string;
}

function HighlightedText({ text, query, className, numberOfLines }: { text: string; query?: string; className?: string; numberOfLines?: number }) {
    if (!query || !query.trim()) {
        return <Text className={className} numberOfLines={numberOfLines}>{text}</Text>;
    }

    const trimmedQuery = query.trim().toLowerCase();
    const parts = text.split(new RegExp(`(${trimmedQuery})`, 'gi'));

    return (
        <Text className={className} numberOfLines={numberOfLines}>
            {parts.map((part, index) => {
                if (part.toLowerCase() === trimmedQuery) {
                    return (
                        <Text key={index} className="text-accent bg-accent/20">
                            {part}
                        </Text>
                    );
                }
                return <React.Fragment key={index}>{part}</React.Fragment>;
            })}
        </Text>
    );
}

export const ListItem = React.memo(function ListItem({
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
    searchQuery = "",
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
                    <HighlightedText text={title} query={searchQuery} className={cn("text-[17px] font-medium text-text", titleClassName)} numberOfLines={1} />
                    {subtitle && (
                        typeof subtitle === "string" ? (
                            <HighlightedText text={subtitle} query={searchQuery} className={cn("text-[14px] text-textMuted mt-0.5", subtitleClassName)} numberOfLines={1} />
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
});
