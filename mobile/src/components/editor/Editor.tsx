import React, { useCallback, useEffect, useRef } from "react";
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
  const lastEditorContentRef = useRef(value || "");

  useEffect(() => {
    const nextValue = value || "";
    latestValueRef.current = nextValue;

    // Prevent cursor jump: don't re-set HTML when change originated from editor typing
    if (nextValue === lastEditorContentRef.current) {
      return;
    }

    lastEditorContentRef.current = nextValue;
    richText.current?.setContentHTML(nextValue);
  }, [value]);

  const handleChange = useCallback((nextContent: string) => {
    lastEditorContentRef.current = nextContent || "";
    onChange(nextContent);
  }, [onChange]);

  return (
    <View className="flex-1 bg-[#101113]">
      <ScrollView
        className="flex-1"
        keyboardDismissMode="on-drag"
        contentContainerStyle={{ flexGrow: 1 }}
      >
        {timestamp && (
          <View className="pt-2 pb-2 items-center">
            <Text className="text-[13px] font-medium text-textMuted uppercase tracking-wider">
              {formatNoteDateTime(timestamp)}
            </Text>
          </View>
        )}
        <RichEditor
          ref={richText}
          initialContentHTML={value}
          onChange={handleChange}
          initialFocus={false}
          editorInitializedCallback={() => {
            richText.current?.setContentHTML(latestValueRef.current || "");
            // Ensure we blur the editor when it is initialized to prevent keyboard auto-open
            richText.current?.blurContentEditor();
          }}
          placeholder={placeholder}
          editorStyle={{
            backgroundColor: "#101113",
            color: "#ffffff",
            placeholderColor: "#636366",
            contentCSSText: "font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.5; padding: 16px; color: white;",
            cssText: "a { color: #eab308 !important; text-decoration: underline; } .x-todo-box { position: static; left: auto; margin-right: 8px; display: inline-flex; align-items: center; vertical-align: middle; } .x-todo-box input { position: static !important; margin: 0; } li:has(.x-todo-box) { list-style-type: none; }"
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
          className="bg-[#26272a] border-t border-white/5"
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
