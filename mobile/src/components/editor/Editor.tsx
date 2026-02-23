import { TextInput, View } from "react-native";

type EditorProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
};

export function Editor({ value, onChange, placeholder = "Start writing..." }: EditorProps) {
  return (
    <View className="flex-1 rounded-xl border border-border bg-surface p-3">
      <TextInput
        multiline
        autoFocus
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor="#6f6f6f"
        textAlignVertical="top"
        className="flex-1 text-[16px] leading-6 text-text"
      />
    </View>
  );
}
