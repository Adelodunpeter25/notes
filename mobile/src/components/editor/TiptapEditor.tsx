import React, { forwardRef, useImperativeHandle, useRef, useEffect, useCallback } from 'react';
import { View, StyleSheet } from 'react-native';
import { WebView, type WebViewMessageEvent } from 'react-native-webview';
import { colors } from '@/theme/colors';
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
  blur: () => void;
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

    // Keep track of the VERY latest value to avoid stale closures in handleMessage
    const currentValueRef = useRef(value);
    useEffect(() => {
      currentValueRef.current = value;
    }, [value]);

    // Use injectJavaScript for highest reliability across RN platforms
    const executeScript = useCallback((script: string) => {
      if (webViewRef.current) {
        webViewRef.current.injectJavaScript(`
          try { ${script} } catch(e) { window.ReactNativeWebView?.postMessage(JSON.stringify({ type: 'log', payload: 'Execute error: ' + e.message })); }
          true;
        `);
      }
    }, []);

    const setWebViewContent = useCallback((newContent: string) => {
      executeScript(`
        if (window.rnUpdateContent) {
          window.rnUpdateContent(${JSON.stringify(newContent || '')});
        }
      `);
    }, [executeScript]);

    useImperativeHandle(ref, () => ({
      toggleBold: () => executeScript(`window.editor?.chain().focus().toggleBold().run();`),
      toggleItalic: () => executeScript(`window.editor?.chain().focus().toggleItalic().run();`),
      toggleStrike: () => executeScript(`window.editor?.chain().focus().toggleStrike().run();`),
      toggleBulletList: () => executeScript(`window.editor?.chain().focus().toggleBulletList().run();`),
      toggleOrderedList: () => executeScript(`window.editor?.chain().focus().toggleOrderedList().run();`),
      toggleTaskList: () => executeScript(`window.editor?.chain().focus().toggleTaskList().run();`),
      undo: () => executeScript(`window.editor?.chain().focus().undo().run();`),
      redo: () => executeScript(`window.editor?.chain().focus().redo().run();`),
      setContent: (content: string) => setWebViewContent(content),
      blur: () => executeScript(`window.editor?.chain().blur().run();`),
    }));

    useEffect(() => {
      if (isReady.current) {
        executeScript(`if (typeof window.editor !== 'undefined' && window.editor.setEditable) { window.editor.setEditable(${editable}); }`);
      }
    }, [editable, executeScript]);

    // Sync content changes from parent to WebView
    useEffect(() => {
      if (isReady.current && value !== lastValue.current) {
        lastValue.current = value;
        setWebViewContent(value);
      }
    }, [value, setWebViewContent]);

    const handleMessage = (event: WebViewMessageEvent) => {
      try {
        const message = JSON.parse(event.nativeEvent.data);
        switch (message.type) {
          case 'log':
            console.log(message.payload);
            break;
          case 'onReady':
            isReady.current = true;
            // Use currentValueRef to guarantee we don't send a stale closure value
            setWebViewContent(currentValueRef.current);
            executeScript(`if (typeof window.editor !== 'undefined' && window.editor.setEditable) { window.editor.setEditable(${editable}); }`);
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
        console.error('[TiptapEditor] Message Parse Error:', e);
      }
    };

    return (
      <View style={styles.container}>
        <WebView
          ref={webViewRef}
          source={{ html: TIPTAP_EDITOR_HTML }}
          onMessage={handleMessage}
          onLoadEnd={() => {
            // Backup init if onReady was missed
            setTimeout(() => {
              if (!isReady.current) {
                isReady.current = true;
                setWebViewContent(currentValueRef.current);
                executeScript(`if (typeof window.editor !== 'undefined' && window.editor.setEditable) { window.editor.setEditable(${editable}); }`);
              }
            }, 300);
          }}
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
          pointerEvents="auto"
        />
      </View>
    );
  }
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  webview: {
    flex: 1,
    backgroundColor: 'transparent',
  },
});
