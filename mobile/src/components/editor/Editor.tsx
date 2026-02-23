import React, { useRef, useEffect } from "react";
import { View, Platform, KeyboardAvoidingView, TextInput } from "react-native";
import { WebView, type WebViewMessageEvent } from "react-native-webview";
import { getTiptapHtml } from "./TiptapWebView";
import { EditorToolbar } from "./EditorToolbar";

type EditorProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
};

export function Editor({ value, onChange, placeholder = "Start writing..." }: EditorProps) {
  const webViewRef = useRef<WebView>(null);
  const isReady = useRef(false);
  const lastContent = useRef(value);
  const [hasWebViewError, setHasWebViewError] = React.useState(false);

  // Initialize source once to prevent reloading the WebView when value changes
  const source = React.useMemo(
    () => ({ html: getTiptapHtml({ initialContent: "", placeholder }) }),
    [placeholder],
  );

  // Sync value prop from parent to WebView
  useEffect(() => {
    if (isReady.current && value !== lastContent.current && webViewRef.current) {
      lastContent.current = value;
      const encodedContent = encodeURIComponent(value);
      webViewRef.current.postMessage(JSON.stringify({ type: "SET_CONTENT", content: encodedContent }));
    }
  }, [value]);

  const onMessage = (event: WebViewMessageEvent) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      if (data.type === "READY") {
        isReady.current = true;
        if (webViewRef.current) {
          const encodedContent = encodeURIComponent(value);
          webViewRef.current.postMessage(JSON.stringify({ type: "SET_CONTENT", content: encodedContent }));
          webViewRef.current.postMessage(JSON.stringify({ type: "FOCUS_EDITOR" }));
        }
      } else if (data.type === "ERROR") {
        setHasWebViewError(true);
      } else if (data.type === "UPDATE") {
        lastContent.current = data.content;
        onChange(data.content);
      }
    } catch (e) {
      console.error("WebView message error:", e);
    }
  };

  const handleAction = (type: string) => {
    if (webViewRef.current) {
      webViewRef.current.postMessage(JSON.stringify({ type }));
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      style={{ flex: 1 }}
    >
      <View style={{ flex: 1, backgroundColor: "#1e1e1e", overflow: "hidden" }}>
        {hasWebViewError ? (
          <View style={{ flex: 1, padding: 12 }}>
            <TextInput
              multiline
              autoFocus
              value={value}
              onChangeText={onChange}
              placeholder={placeholder}
              placeholderTextColor="#6f6f6f"
              textAlignVertical="top"
              style={{ flex: 1, color: "#fff", fontSize: 16, lineHeight: 24 }}
            />
          </View>
        ) : (
          <WebView
            ref={webViewRef}
            originWhitelist={["*"]}
            source={source}
            onMessage={onMessage}
            scrollEnabled={true}
            style={{ flex: 1, backgroundColor: "#1e1e1e" }}
            keyboardDisplayRequiresUserAction={false}
            textInteractionEnabled={true}
            hideKeyboardAccessoryView={true}
            domStorageEnabled={true}
            javaScriptEnabled={true}
          />
        )}
        <EditorToolbar onAction={handleAction} />
      </View>
    </KeyboardAvoidingView>
  );
}
