import React from "react";
import { Modal, TouchableWithoutFeedback, View, Text, Pressable, PressableStateCallbackType } from "react-native";
import { LucideIcon } from "lucide-react-native";

export interface ContextMenuItem {
    label: string;
    icon?: LucideIcon;
    onPress: () => void;
    destructive?: boolean;
}

export interface ContextMenuProps {
    visible: boolean;
    onClose: () => void;
    items: (ContextMenuItem | "separator")[];
    title?: string;
    anchor?: { x: number; y: number } | null;
}

export function ContextMenu({ visible, onClose, items, title, anchor }: ContextMenuProps) {
    const getItemStyle = ({ pressed }: PressableStateCallbackType) => [
        { backgroundColor: pressed ? "rgba(255, 255, 255, 0.1)" : "transparent" }
    ];

    const menuWidth = 280;
    const estimatedHeight = (title ? 52 : 0) + items.length * 50 + 12;
    const left = Math.max(12, Math.min((anchor?.x ?? 20) - 20, 390 - menuWidth));
    const top = Math.max(56, Math.min((anchor?.y ?? 120) + 8, 844 - estimatedHeight));

    return (
        <Modal
            visible={visible}
            transparent
            animationType="none"
            onRequestClose={onClose}
        >
            <TouchableWithoutFeedback onPress={onClose}>
                <View className="flex-1 bg-black/40">
                    <TouchableWithoutFeedback>
                        <View
                            className="absolute w-[280px] bg-[#2c2c2e] rounded-2xl overflow-hidden shadow-2xl"
                            style={{ left, top }}
                        >
                            {title && (
                                <View className="px-4 py-3 border-b border-white/10">
                                    <Text className="text-textMuted text-xs font-semibold uppercase tracking-wider text-center">
                                        {title}
                                    </Text>
                                </View>
                            )}

                            <View>
                                {items.map((item, index) => {
                                    if (item === "separator") {
                                        return (
                                            <View
                                                key={`sep-${index}`}
                                                className="h-[0.5px] bg-white/10 mx-4"
                                            />
                                        );
                                    }

                                    const Icon = item.icon;
                                    return (
                                        <Pressable
                                            key={item.label}
                                            onPress={() => {
                                                item.onPress();
                                                onClose();
                                            }}
                                            style={getItemStyle}
                                            className="flex-row items-center justify-between px-4 py-3.5"
                                        >
                                            <Text className={`text-[17px] ${item.destructive ? "text-danger" : "text-text"}`}>
                                                {item.label}
                                            </Text>
                                            {Icon && (
                                                <Icon
                                                    size={20}
                                                    color={item.destructive ? "#ff4444" : "#eab308"}
                                                />
                                            )}
                                        </Pressable>
                                    );
                                })}
                            </View>
                        </View>
                    </TouchableWithoutFeedback>
                </View>
            </TouchableWithoutFeedback>
        </Modal>
    );
}
