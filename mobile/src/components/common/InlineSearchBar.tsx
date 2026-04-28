import React from "react";
import { Pressable, Text, View } from "react-native";
import { Search } from "lucide-react-native";
import { cn } from "@shared-utils/cn";

type InlineSearchBarProps = {
  placeholder?: string;
  onPress: () => void;
  className?: string;
};

export function InlineSearchBar({
  placeholder = "Search",
  onPress,
  className,
}: InlineSearchBarProps) {
  return (
    <Pressable
      onPress={onPress}
      className={cn(
        "mx-4 mt-3 flex-row items-center rounded-xl bg-surfaceSecondary px-3 py-3",
        className,
      )}
      accessibilityRole="button"
      accessibilityLabel="Search"
    >
      <Search size={18} color="#8b8b8b" />
      <Text className="ml-2 text-[15px] text-textMuted">{placeholder}</Text>
      <View className="flex-1" />
    </Pressable>
  );
}

