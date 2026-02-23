import React, { useEffect, useRef } from "react";
import { ScrollView, Platform, KeyboardAvoidingView, View, Text } from "react-native";
import { formatNoteDateTime } from "@/utils/formatDate";
import { actions, RichEditor, RichToolbar } from "react-native-pell-rich-editor";
import { useSafeAreaInsets } from "react-native-safe-area-context";

type EditorProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  timestamp?: string;
};

export function Editor({ value, onChange, placeholder = "Start writing...", timestamp }: EditorProps) {
  const richText = useRef<RichEditor>(null);
  const insets = useSafeAreaInsets();
  const latestValueRef = useRef(value);

  useEffect(() => {
    latestValueRef.current = value;
    richText.current?.setContentHTML(value || "");
  }, [value]);

  useEffect(() => {
    const timeout = setTimeout(() => {
      richText.current?.focusContentEditor();
    }, 120);

    return () => clearTimeout(timeout);
  }, []);

  return (
    <View className="flex-1 bg-background">
      <ScrollView
        className="flex-1"
        keyboardDismissMode="on-drag"
        contentContainerStyle={{ flexGrow: 1 }}
      >
        {timestamp && (
          <View className="pt-6 pb-2 items-center">
            <Text className="text-[13px] font-medium text-textMuted uppercase tracking-wider">
              {formatNoteDateTime(timestamp)}
            </Text>
          </View>
        )}
        <RichEditor
          ref={richText}
          initialContentHTML={value}
          onChange={onChange}
          editorInitializedCallback={() => {
            richText.current?.setContentHTML(latestValueRef.current || "");
            richText.current?.focusContentEditor();
          }}
          placeholder={placeholder}
          editorStyle={{
            backgroundColor: "#1c1c1e",
            color: "#ffffff",
            placeholderColor: "#636366",
            contentCSSText: "font-family: -apple-system, sans-serif; font-size: 17px; line-height: 1.5; padding: 16px; color: white;",
            cssText: "a { color: #eab308 !important; text-decoration: underline; }"
          }}
          useContainer={false}
          initialHeight={500}
        />
      </ScrollView>

      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : "height"}
        keyboardVerticalOffset={Platform.OS === "ios" ? 80 : 0}
      >
        <View
          style={{ paddingBottom: Platform.OS === "ios" ? insets.bottom : 8 }}
          className="bg-[#2c2c2e] border-t border-white/5"
        >
          <RichToolbar
            editor={richText}
            actions={[
              actions.setBold,
              actions.setItalic,
              actions.setStrikethrough,
              actions.insertBulletsList,
              actions.insertOrderedList,
              actions.checkboxList,
              actions.undo,
              actions.redo,
            ]}
            iconTint="#ffffff"
            selectedIconTint="#eab308"
            disabledIconTint="#48484a"
            style={{
              backgroundColor: "transparent",
            }}
          />
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}
