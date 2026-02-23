import React, { useRef, useEffect } from "react";
import { View, Platform } from "react-native";
import { WebView, type WebViewMessageEvent } from "react-native-webview";
import { getTiptapHtml } from "./TiptapWebView";

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

  return (
    <View className="flex-1 bg-background overflow-hidden">
      <WebView
        ref={webViewRef}
        originWhitelist={["*"]}
        source={{ html: getTiptapHtml(value) }}
        onMessage={onMessage}
        scrollEnabled={true}
        className="flex-1 bg-background"
        style={{ backgroundColor: "#1e1e1e" }}
        autoFocus={true}
        keyboardDisplayRequiresUserAction={false}
        textInteractionEnabled={true}
      />
    </View>
  );
}
