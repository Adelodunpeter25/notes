import React, { useCallback, useEffect, useRef, useState } from "react";
import { ScrollView, Platform, Keyboard, View, Text } from "react-native";
import { formatNoteDateTime } from "@/utils/formatDate";
import { actions, RichEditor, RichToolbar } from "react-native-pell-rich-editor";
import { useSafeAreaInsets } from "react-native-safe-area-context";

type EditorProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  timestamp?: string;
  editable?: boolean;
};

const EDITOR_SURFACE_COLOR = "#1A1B1E";

export function Editor({
  value,
  onChange,
  placeholder = "Start writing...",
  timestamp,
  editable = true,
}: EditorProps) {
  const richText = useRef<RichEditor>(null);
  const insets = useSafeAreaInsets();
  const latestValueRef = useRef(value);
  const lastEditorContentRef = useRef(value || "");
  const [keyboardHeight, setKeyboardHeight] = useState(0);

  useEffect(() => {
    const nextValue = value || "";
    latestValueRef.current = nextValue;

    // While actively editing, never force HTML from props.
    // This prevents cursor/selection resets during autosave or cache updates.
    if (editable) {
      return;
    }

    // Prevent cursor jump: don't re-set HTML when change originated from editor typing
    if (nextValue === lastEditorContentRef.current) {
      return;
    }

    lastEditorContentRef.current = nextValue;
    richText.current?.setContentHTML(nextValue);
  }, [editable, value]);

  const handleChange = useCallback((nextContent: string) => {
    lastEditorContentRef.current = nextContent || "";
    onChange(nextContent);
  }, [onChange]);

  useEffect(() => {
    if (!editable) {
      return;
    }

    const interval = setInterval(() => {
      richText.current?.getContentHtml()?.then((currentHtml) => {
        const nextContent = currentHtml || "";
        if (nextContent === lastEditorContentRef.current) {
          return;
        }

        lastEditorContentRef.current = nextContent;
        onChange(nextContent);
      }).catch(() => {
        // Ignore transient WebView bridge errors
      });
    }, 700);

    return () => clearInterval(interval);
  }, [editable, onChange]);

  useEffect(() => {
    if (!editable) {
      setKeyboardHeight(0);
      return;
    }

    if (Platform.OS === "ios") {
      const frameSub = Keyboard.addListener("keyboardWillChangeFrame", (event) => {
        const height = Math.max(0, event.endCoordinates.height - insets.bottom);
        setKeyboardHeight(height);
      });
      const hideSub = Keyboard.addListener("keyboardWillHide", () => {
        setKeyboardHeight(0);
      });

      return () => {
        frameSub.remove();
        hideSub.remove();
      };
    }

    const showSub = Keyboard.addListener("keyboardDidShow", (event) => {
      setKeyboardHeight(event.endCoordinates.height);
    });
    const hideSub = Keyboard.addListener("keyboardDidHide", () => {
      setKeyboardHeight(0);
    });

    return () => {
      showSub.remove();
      hideSub.remove();
    };
  }, [editable, insets.bottom]);

  return (
    <View style={{ backgroundColor: EDITOR_SURFACE_COLOR }} className="flex-1">
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
          disabled={!editable}
          initialFocus={false}
          editorInitializedCallback={() => {
            richText.current?.setContentHTML(latestValueRef.current || "");
            // Ensure we blur the editor when it is initialized to prevent keyboard auto-open
            richText.current?.blurContentEditor();
          }}
          placeholder={placeholder}
          editorStyle={{
            backgroundColor: EDITOR_SURFACE_COLOR,
            color: "#ffffff",
            placeholderColor: "#636366",
            contentCSSText:
              "font-family: -apple-system, sans-serif; font-size: 15px; line-height: 1.5; padding: 16px; color: white; " +
              "max-width: 100%; overflow-x: hidden; overflow-wrap: anywhere; word-break: break-word; white-space: pre-wrap;",
            cssText:
              "html, body { overflow-x: hidden !important; max-width: 100% !important; } " +
              "* { max-width: 100% !important; box-sizing: border-box !important; } " +
              "p, div, span, li { max-width: 100% !important; overflow-wrap: anywhere !important; word-break: break-word !important; } " +
              "pre, code { white-space: pre-wrap !important; word-break: break-word !important; overflow-wrap: anywhere !important; } " +
              "a { color: #eab308 !important; text-decoration: underline; white-space: normal !important; overflow-wrap: anywhere !important; word-break: break-all !important; } " +
              ".x-todo-box { position: static !important; left: auto !important; margin-right: 8px; display: inline-flex !important; align-items: center; vertical-align: middle; white-space: nowrap; } " +
              ".x-todo-box input { position: static !important; margin: 0 !important; } " +
              "ul.task-list, ul[data-type='taskList'], ul.x-todo-list { margin-left: 0 !important; padding-left: 0 !important; } " +
              "li.task-list-item, li[data-type='taskItem'], li.x-todo-item { margin-left: 0 !important; padding-left: 0 !important; text-indent: 0 !important; } " +
              ".x-todo-box + span, .x-todo-box + div, .x-todo-box + p { display: inline !important; } " +
              "ul.x-todo-list > li, ul.task-list > li, ul[data-type='taskList'] > li { list-style: none !important; display: flex !important; align-items: flex-start !important; gap: 8px !important; margin: 0 !important; padding: 0 !important; } " +
              "ul.x-todo-list > li > .x-todo-box, ul.task-list > li > .x-todo-box, ul[data-type='taskList'] > li > .x-todo-box { float: none !important; flex: 0 0 auto !important; margin: 1px 0 0 0 !important; } " +
              "ul.x-todo-list > li > *, ul.task-list > li > *, ul[data-type='taskList'] > li > * { min-width: 0; line-height: 1.5; } " +
              "ul.x-todo-list > li > span, ul.x-todo-list > li > p, ul.x-todo-list > li > div, ul.task-list > li > span, ul.task-list > li > p, ul.task-list > li > div, ul[data-type='taskList'] > li > span, ul[data-type='taskList'] > li > p, ul[data-type='taskList'] > li > div { flex: 1 1 auto; white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; margin: 0 !important; }",
          }}
          useContainer={false}
          initialHeight={500}
        />
      </ScrollView>

      <View
        style={{
          marginBottom: keyboardHeight,
          paddingBottom: Platform.OS === "ios" ? insets.bottom : 8,
        }}
        className="border-t border-white/5"
      >
        <View style={{ backgroundColor: EDITOR_SURFACE_COLOR }}>
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
              opacity: editable ? 1 : 0.45,
            }}
          />
        </View>
      </View>
    </View>
  );
}
