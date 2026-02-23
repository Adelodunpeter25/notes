import React from "react";
import { Modal, View, Text, StyleSheet, TouchableWithoutFeedback } from "react-native";
import { AppleNotesIcon } from "./AppleNotesIcon";
import { Button } from "./Button";

interface ConfirmDialogProps {
    visible: boolean;
    title: string;
    description?: string;
    confirmLabel: string;
    cancelLabel?: string;
    onConfirm: () => void;
    onCancel: () => void;
    destructive?: boolean;
}

export function ConfirmDialog({
    visible,
    title,
    description,
    confirmLabel,
    cancelLabel = "Cancel",
    onConfirm,
    onCancel,
    destructive = false,
}: ConfirmDialogProps) {
    return (
        <Modal
            visible={visible}
            transparent
            animationType="fade"
            onRequestClose={onCancel}
        >
            <TouchableWithoutFeedback onPress={onCancel}>
                <View style={styles.overlay}>
                    <TouchableWithoutFeedback>
                        <View className="w-[85%] max-w-[340px] bg-surface rounded-3xl p-6 items-center shadow-2xl border border-border/50">
                            <AppleNotesIcon className="mb-4" />

                            <Text className="text-xl font-bold text-text text-center mb-2">
                                {title}
                            </Text>

                            {description && (
                                <Text className="text-[15px] text-textMuted text-center mb-6">
                                    {description}
                                </Text>
                            )}

                            <View className="flex-col w-full gap-2">
                                <Button
                                    title={confirmLabel}
                                    variant={destructive ? "danger" : "primary"}
                                    onPress={onConfirm}
                                    className="w-full"
                                />
                                <Button
                                    title={cancelLabel}
                                    variant="ghost"
                                    onPress={onCancel}
                                    className="w-full"
                                />
                            </View>
                        </View>
                    </TouchableWithoutFeedback>
                </View>
            </TouchableWithoutFeedback>
        </Modal>
    );
}

const styles = StyleSheet.create({
    overlay: {
        flex: 1,
        backgroundColor: "rgba(0, 0, 0, 0.6)",
        justifyContent: "center",
        alignItems: "center",
    },
});
