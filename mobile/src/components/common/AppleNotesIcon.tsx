import React from "react";
import { View } from "react-native";
import { cn } from "@/utils/cn";

interface AppleNotesIconProps {
    className?: string;
}

export function AppleNotesIcon({ className }: AppleNotesIconProps) {
    return (
        <View className={cn("h-12 w-12 flex-col overflow-hidden rounded-[10px] shadow-sm", className)}>
            <View className="h-[15px] w-full border-b border-[#e1b238] bg-[#f6c33e]" />
            <View className="flex-1 w-full bg-[#fcfcfc] flex flex-col pt-[5px] gap-[4px]">
                <View className="h-[1px] w-full bg-black/10 mx-auto max-w-[90%]" />
                <View className="h-[1px] w-full bg-black/10 mx-auto max-w-[90%]" />
                <View className="h-[1px] w-full bg-black/10 mx-auto max-w-[90%]" />
            </View>
        </View>
    );
}
