import React from "react";
import { View, TouchableOpacity, ScrollView } from "react-native";
import {
    Bold,
    Italic,
    Strikethrough,
    List,
    ListOrdered,
    CheckSquare,
    Type
} from "lucide-react-native";
import { cn } from "@/utils/cn";

interface EditorToolbarProps {
    onAction: (type: string) => void;
    className?: string;
}

export function EditorToolbar({ onAction, className }: EditorToolbarProps) {
    const actions = [
        { type: "TOGGLE_BOLD", icon: Bold },
        { type: "TOGGLE_ITALIC", icon: Italic },
        { type: "TOGGLE_STRIKE", icon: Strikethrough },
        { type: "TOGGLE_BULLET_LIST", icon: List },
        { type: "TOGGLE_ORDERED_LIST", icon: ListOrdered },
        { type: "TOGGLE_TASK_LIST", icon: CheckSquare },
    ];

    return (
        <View className={cn("bg-surface border-t border-border px-2 py-2", className)}>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                <View className="flex-row items-center gap-1">
                    {actions.map((action) => (
                        <TouchableOpacity
                            key={action.type}
                            onPress={() => onAction(action.type)}
                            className="p-2 rounded-lg active:bg-surfaceSecondary"
                        >
                            <action.icon size={20} color="#ffffff" />
                        </TouchableOpacity>
                    ))}
                </View>
            </ScrollView>
        </View>
    );
}
