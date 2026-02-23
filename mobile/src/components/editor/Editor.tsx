import { useEffect, useRef } from "react";
import { KeyboardAvoidingView, Platform, View } from "react-native";
import { RichText, Toolbar, useEditorBridge } from "@10play/tentap-editor";

type EditorProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
};

export function Editor({ value, onChange, placeholder = "Start writing..." }: EditorProps) {
  void placeholder;
  const lastKnownContentRef = useRef(value);
  const editorRef = useRef<ReturnType<typeof useEditorBridge> | null>(null);

  const editor = useEditorBridge({
    autofocus: true,
    avoidIosKeyboard: true,
    initialContent: value || "<p></p>",
    onChange: () => {
      void editorRef.current?.getHTML().then((html) => {
        if (html === lastKnownContentRef.current) {
          return;
        }
        lastKnownContentRef.current = html;
        onChange(html);
      });
    },
  });

  editorRef.current = editor;

  useEffect(() => {
    if (!editorRef.current) {
      return;
    }
    if (value === lastKnownContentRef.current) {
      return;
    }

    lastKnownContentRef.current = value;
    editorRef.current.setContent(value || "<p></p>");
  }, [value]);

  useEffect(() => {
    if (!editorRef.current) {
      return;
    }

    editorRef.current.focus("end");
  }, [editor]);

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      style={{ flex: 1 }}
    >
      <View style={{ flex: 1, backgroundColor: "#1e1e1e" }}>
        <RichText editor={editor} />
        <View style={{ borderTopWidth: 1, borderTopColor: "#3e3e3e", backgroundColor: "#252525" }}>
          <Toolbar editor={editor} />
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}
