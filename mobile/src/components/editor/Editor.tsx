import React, { useRef, useEffect } from "react";
import { View, Platform, KeyboardAvoidingView } from "react-native";
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
  const lastContent = useRef(value);

  // Sync value prop from parent to WebView (only if it significantly differs from our cache)
  useEffect(() => {
    if (value !== lastContent.current && webViewRef.current) {
      lastContent.current = value;
      const message = JSON.stringify({ type: "SET_CONTENT", content: value });
      webViewRef.current.postMessage(message);
    }
  }, [value]);

  const onMessage = (event: WebViewMessageEvent) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      if (data.type === "UPDATE") {
        lastContent.current = data.content;
        onChange(data.content);
      }
    } catch (e) {
      console.error("WebView message error:", e);
    }
  };

  const handleAction = (type: string) => {
    if (webViewRef.current) {
      const message = JSON.stringify({ type });
      webViewRef.current.postMessage(message);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      className="flex-1"
    >
      <View className="flex-1 bg-background overflow-hidden">
        <WebView
          ref={webViewRef}
          originWhitelist={["*"]}
          source={{ html: getTiptapHtml(value) }}
          onMessage={onMessage}
          scrollEnabled={true}
          className="flex-1 bg-background"
          style={{ backgroundColor: "#1e1e1e" }}
          keyboardDisplayRequiresUserAction={false}
          textInteractionEnabled={true}
          hideKeyboardAccessoryView={true}
        />
        <EditorToolbar onAction={handleAction} />
      </View>
    </KeyboardAvoidingView>
  );
}
