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
  const isReady = useRef(false);
  const lastContent = useRef(value);

  // Initialize source once to prevent reloading the WebView when value changes
  const source = React.useMemo(() => ({ html: getTiptapHtml("") }), []);

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
        if (value && webViewRef.current) {
          const encodedContent = encodeURIComponent(value);
          webViewRef.current.postMessage(JSON.stringify({ type: "SET_CONTENT", content: encodedContent }));
        }
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
      className="flex-1"
    >
      <View className="flex-1 bg-background overflow-hidden">
        <WebView
          ref={webViewRef}
          originWhitelist={["*"]}
          source={source}
          onMessage={onMessage}
          scrollEnabled={true}
          className="flex-1 bg-background"
          style={{ backgroundColor: "#1e1e1e" }}
          keyboardDisplayRequiresUserAction={false}
          textInteractionEnabled={true}
          hideKeyboardAccessoryView={true}
          domStorageEnabled={true}
          javaScriptEnabled={true}
        />
        <EditorToolbar onAction={handleAction} />
      </View>
    </KeyboardAvoidingView>
  );
}
