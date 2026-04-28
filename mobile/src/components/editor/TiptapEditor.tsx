import React, { forwardRef, useImperativeHandle, useRef, useEffect, useCallback } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { WebView, type WebViewMessageEvent } from 'react-native-webview';
import { TIPTAP_EDITOR_HTML } from './editor-html';

export type TiptapEditorRef = {
  toggleBold: () => void;
  toggleItalic: () => void;
  toggleStrike: () => void;
  toggleBulletList: () => void;
  toggleOrderedList: () => void;
  toggleTaskList: () => void;
  undo: () => void;
  redo: () => void;
  setContent: (content: string) => void;
};

type TiptapEditorProps = {
  value: string;
  onChange: (value: string) => void;
  onFocus?: () => void;
  onBlur?: () => void;
  editable?: boolean;
};

export const TiptapEditor = forwardRef<TiptapEditorRef, TiptapEditorProps>(
  ({ value, onChange, onFocus, onBlur, editable = true }, ref) => {
    const webViewRef = useRef<WebView>(null);
    const isReady = useRef(false);
    const lastValue = useRef(value);

    const postMessage = useCallback((type: string, payload?: any) => {
      webViewRef.current?.postMessage(JSON.stringify({ type, payload }));
    }, []);

    useImperativeHandle(ref, () => ({
      toggleBold: () => postMessage('toggleBold'),
      toggleItalic: () => postMessage('toggleItalic'),
      toggleStrike: () => postMessage('toggleStrike'),
      toggleBulletList: () => postMessage('toggleBulletList'),
      toggleOrderedList: () => postMessage('toggleOrderedList'),
      toggleTaskList: () => postMessage('toggleTaskList'),
      undo: () => postMessage('undo'),
      redo: () => postMessage('redo'),
      setContent: (content: string) => postMessage('setContent', content),
    }));

    useEffect(() => {
      if (isReady.current && value !== lastValue.current) {
        lastValue.current = value;
        postMessage('setContent', value);
      }
    }, [value, postMessage]);

    const handleMessage = (event: WebViewMessageEvent) => {
      try {
        const message = JSON.parse(event.nativeEvent.data);
        switch (message.type) {
          case 'onReady':
            isReady.current = true;
            postMessage('setContent', value);
            break;
          case 'onChange':
            lastValue.current = message.payload;
            onChange(message.payload);
            break;
          case 'onFocus':
            onFocus?.();
            break;
          case 'onBlur':
            onBlur?.();
            break;
        }
      } catch (e) {
        console.error('Error parsing message from WebView:', e);
      }
    };

    return (
      <View style={styles.container}>
        <WebView
          ref={webViewRef}
          source={{ html: TIPTAP_EDITOR_HTML }}
          onMessage={handleMessage}
          scrollEnabled={true}
          overScrollMode="never"
          bounces={false}
          style={styles.webview}
          originWhitelist={['*']}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          textZoom={100}
          keyboardDisplayRequiresUserAction={false}
          hideKeyboardAccessoryView={true}
          pointerEvents={editable ? 'auto' : 'none'}
        />
      </View>
    );
  }
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1A1B1E',
  },
  webview: {
    flex: 1,
    backgroundColor: 'transparent',
  },
});
