import React from "react";
import { Pressable, Text, View, TextInput } from "react-native";
import { Search } from "lucide-react-native";
import { cn } from "@shared-utils/cn";
import { colors } from "@/theme/colors";

type InlineSearchBarProps = {
  placeholder?: string;
  onPress?: () => void;
  value?: string;
  onChangeText?: (text: string) => void;
  className?: string;
};

export function InlineSearchBar({
  placeholder = "Search",
  onPress,
  value,
  onChangeText,
  className,
}: InlineSearchBarProps) {
  const containerClass = cn(
    "mx-4 mt-3 flex-row items-center rounded-xl bg-surfaceSecondary px-3 py-1.5",
    className,
  );

  if (onChangeText !== undefined) {
    return (
      <View className={containerClass}>
        <Search size={16} color={colors.textMuted} />
        <TextInput
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={colors.placeholder}
          className="ml-2 flex-1 py-1 text-[15px] text-text"
        />
      </View>
    );
  }

  return (
    <Pressable
      onPress={onPress}
      className={containerClass}
      accessibilityRole="button"
      accessibilityLabel="Search"
    >
      <Search size={16} color={colors.textMuted} />
      <Text className="ml-2 py-1 text-[15px] text-textMuted">{placeholder}</Text>
      <View className="flex-1" />
    </Pressable>
  );
}
