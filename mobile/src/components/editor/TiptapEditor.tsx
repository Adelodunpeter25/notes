import React, { forwardRef, useImperativeHandle, useRef, useEffect, useCallback } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { WebView, type WebViewMessageEvent } from 'react-native-webview';
import { TIPTAP_EDITOR_HTML } from './editor-html';

export type TiptapEditorRef = {
  toggleBold: () => void;
  toggleItalic: () => void;
  toggleUnderline: () => void;
  toggleStrike: () => void;
  toggleCode: () => void;
  toggleCodeBlock: () => void;
  toggleBlockquote: () => void;
  toggleBulletList: () => void;
  toggleOrderedList: () => void;
  toggleTaskList: () => void;
  setHeading: (level: 1 | 2 | 3) => void;
  setParagraph: () => void;
  setTextAlign: (align: "left" | "center" | "right" | "justify") => void;
  indent: () => void;
  outdent: () => void;
  insertHorizontalRule: () => void;
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
      console.log('[RN] setWebViewContent called, length:', newContent ? newContent.length : 0);
      executeScript(`
        if (window.rnUpdateContent) {
          window.rnUpdateContent(${JSON.stringify(newContent || '')});
        }
      `);
    }, [executeScript]);

    useImperativeHandle(ref, () => ({
      toggleBold: () => executeScript(`window.editor?.chain().focus().toggleBold().run();`),
      toggleItalic: () => executeScript(`window.editor?.chain().focus().toggleItalic().run();`),
      toggleUnderline: () => executeScript(`window.editor?.chain().focus().toggleUnderline().run();`),
      toggleStrike: () => executeScript(`window.editor?.chain().focus().toggleStrike().run();`),
      toggleCode: () => executeScript(`window.editor?.chain().focus().toggleCode().run();`),
      toggleCodeBlock: () => executeScript(`window.editor?.chain().focus().toggleCodeBlock().run();`),
      toggleBlockquote: () => executeScript(`window.editor?.chain().focus().toggleBlockquote().run();`),
      toggleBulletList: () => executeScript(`window.editor?.chain().focus().toggleBulletList().run();`),
      toggleOrderedList: () => executeScript(`window.editor?.chain().focus().toggleOrderedList().run();`),
      toggleTaskList: () => executeScript(`window.editor?.chain().focus().toggleTaskList().run();`),
      setHeading: (level) =>
        executeScript(`window.editor?.chain().focus().setHeading({ level: ${level} }).run();`),
      setParagraph: () => executeScript(`window.editor?.chain().focus().setParagraph().run();`),
      setTextAlign: (align) =>
        executeScript(`window.editor?.chain().focus().setTextAlign(${JSON.stringify(align)}).run();`),
      indent: () => executeScript(`window.editor?.chain().focus().indent().run();`),
      outdent: () => executeScript(`window.editor?.chain().focus().outdent().run();`),
      insertHorizontalRule: () => executeScript(`window.editor?.chain().focus().setHorizontalRule().run();`),
      undo: () => executeScript(`window.editor?.chain().focus().undo().run();`),
      redo: () => executeScript(`window.editor?.chain().focus().redo().run();`),
      setContent: (content: string) => setWebViewContent(content),
      blur: () => executeScript(`window.editor?.chain().blur().run();`),
    }));

    // Sync editable state
    useEffect(() => {
      if (isReady.current) {
        executeScript(`if (window.editor) { window.editor.setEditable(${editable}); }`);
      }
    }, [editable, executeScript]);

    // Sync content changes from parent to WebView
    useEffect(() => {
      if (isReady.current && value !== lastValue.current) {
        console.log('[RN] Props value changed, syncing to WebView');
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
            console.log('[RN] Received onReady from WebView');
            isReady.current = true;
            // Use currentValueRef to guarantee we don't send a stale closure value
            setWebViewContent(currentValueRef.current);
            executeScript(`if (window.editor) { window.editor.setEditable(${editable}); }`);
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
                console.log('[RN] onLoadEnd timeout: isReady false, forcing init');
                isReady.current = true;
                setWebViewContent(currentValueRef.current);
                executeScript(`if (window.editor) { window.editor.setEditable(${editable}); }`);
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
    backgroundColor: '#1A1B1E',
  },
  webview: {
    flex: 1,
    backgroundColor: 'transparent',
  },
});
