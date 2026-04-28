import React, { useEffect, useRef, useState } from "react";
import { ScrollView, Platform, Keyboard, View, Text, TouchableOpacity, StyleSheet } from "react-native";
import { formatNoteDateTime } from "@shared-utils/formatDate";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { TiptapEditor, type TiptapEditorRef } from "./TiptapEditor";
import { 
  Bold, 
  Italic, 
  Strikethrough, 
  List, 
  ListOrdered, 
  CheckSquare, 
  Undo2, 
  Redo2 
} from "lucide-react-native";

type EditorProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  timestamp?: string;
  editable?: boolean;
};

const EDITOR_SURFACE_COLOR = "#1A1B1E";

const ToolbarButton = ({ 
  onPress, 
  icon: Icon, 
  active = false 
}: { 
  onPress: () => void; 
  icon: any; 
  active?: boolean 
}) => (
  <TouchableOpacity
    onPress={onPress}
    className={`p-2 rounded-md mr-1 ${active ? 'bg-yellow-500/20' : ''}`}
  >
    <Icon size={20} color={active ? "#eab308" : "#ffffff"} />
  </TouchableOpacity>
);

export function Editor({
  value,
  onChange,
  placeholder = "Start writing...",
  timestamp,
  editable = true,
}: EditorProps) {
  const editorRef = useRef<TiptapEditorRef>(null);
  const insets = useSafeAreaInsets();
  const [keyboardHeight, setKeyboardHeight] = useState(0);

  useEffect(() => {
    if (!editable) {
      setKeyboardHeight(0);
      return;
    }

    const showSub = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow",
      (event) => {
        const height = Platform.OS === "ios" 
          ? Math.max(0, event.endCoordinates.height - insets.bottom)
          : event.endCoordinates.height;
        setKeyboardHeight(height);
      }
    );
    const hideSub = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide",
      () => {
        setKeyboardHeight(0);
      }
    );

    return () => {
      showSub.remove();
      hideSub.remove();
    };
  }, [editable, insets.bottom]);

  return (
    <View style={{ backgroundColor: EDITOR_SURFACE_COLOR }} className="flex-1">
      <View 
        className="flex-1"
      >
        {timestamp && (
          <View className="pt-2 pb-2 items-center">
            <Text className="text-[13px] font-medium text-textMuted uppercase tracking-wider">
              {formatNoteDateTime(timestamp)}
            </Text>
          </View>
        )}
        <TiptapEditor
          ref={editorRef}
          value={value}
          onChange={onChange}
          editable={editable}
        />
      </View>

      {editable && (
        <View
          style={{
            marginBottom: keyboardHeight,
            paddingBottom: Platform.OS === "ios" && keyboardHeight === 0 ? insets.bottom : 8,
          }}
          className="border-t border-white/5 bg-[#1A1B1E]"
        >
          <ScrollView 
            horizontal 
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ paddingHorizontal: 12, paddingVertical: 8 }}
          >
            <ToolbarButton 
              icon={Bold} 
              onPress={() => editorRef.current?.toggleBold()} 
            />
            <ToolbarButton 
              icon={Italic} 
              onPress={() => editorRef.current?.toggleItalic()} 
            />
            <ToolbarButton 
              icon={Strikethrough} 
              onPress={() => editorRef.current?.toggleStrike()} 
            />
            <View className="w-[1px] h-6 bg-white/10 mx-2 self-center" />
            <ToolbarButton 
              icon={List} 
              onPress={() => editorRef.current?.toggleBulletList()} 
            />
            <ToolbarButton 
              icon={ListOrdered} 
              onPress={() => editorRef.current?.toggleOrderedList()} 
            />
            <ToolbarButton 
              icon={CheckSquare} 
              onPress={() => editorRef.current?.toggleTaskList()} 
            />
            <View className="w-[1px] h-6 bg-white/10 mx-2 self-center" />
            <ToolbarButton 
              icon={Undo2} 
              onPress={() => editorRef.current?.undo()} 
            />
            <ToolbarButton 
              icon={Redo2} 
              onPress={() => editorRef.current?.redo()} 
            />
          </ScrollView>
        </View>
      )}
    </View>
  );
}
