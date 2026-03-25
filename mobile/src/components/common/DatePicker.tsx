import React, { useState } from "react";
import { View, Text, Pressable, Platform } from "react-native";
import { X, Calendar } from "lucide-react-native";
import DateTimePicker, { type DateTimePickerEvent } from "@react-native-community/datetimepicker";
import { cn } from "@shared-utils/cn";

interface DatePickerProps {
    value: Date | null;
    onChange: (date: Date | null) => void;
    label?: string;
    placeholder?: string;
    className?: string;
}

export function DatePicker({ value, onChange, label, placeholder = "Set a date", className }: DatePickerProps) {
    const [show, setShow] = useState(false);

    const handleDateChange = (event: DateTimePickerEvent, selectedDate?: Date) => {
        // On Android, the picker closes immediately after selection.
        // On iOS, it can stay open if in spinner mode, but here we trigger on 'set'
        if (Platform.OS === "android") {
            setShow(false);
        }
        
        if (event.type === "set") {
            if (selectedDate) {
                onChange(selectedDate);
            }
        } else if (event.type === "dismissed") {
            setShow(false);
        }

        // For iOS spinner, we might want a "Done" button if we were using a modal, 
        // but the current implementation in TaskModal just closed it.
        if (Platform.OS === "ios" && event.type !== "set") {
             // do nothing, let them spin
        } else if (Platform.OS === "ios" && event.type === "set") {
             setShow(false);
        }
    };

    return (
        <View className={className}>
            {label && (
                <Text className="text-[13px] font-semibold text-textMuted uppercase tracking-wider mb-2">
                    {label}
                </Text>
            )}
            <Pressable
                onPress={() => setShow(true)}
                className="flex-row items-center bg-surfaceSecondary/50 rounded-xl px-4 py-3 border border-border/30"
            >
                <Text className={cn("text-[15px]", value ? "text-text font-medium" : "text-textMuted")}>
                    {value ? value.toLocaleDateString() : placeholder}
                </Text>
                {value && (
                    <Pressable
                        onPress={(e) => {
                            e.stopPropagation();
                            onChange(null);
                        }}
                        className="ml-auto p-1"
                    >
                        <X size={16} color="#ef4444" />
                    </Pressable>
                )}
            </Pressable>

            {show && (
                <DateTimePicker
                    value={value || new Date()}
                    mode="date"
                    display={Platform.OS === "ios" ? "spinner" : "default"}
                    onChange={handleDateChange}
                    minimumDate={new Date()}
                    themeVariant="dark"
                    textColor="white"
                />
            )}
        </View>
    );
}
