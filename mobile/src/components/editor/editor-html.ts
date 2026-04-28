export const TIPTAP_EDITOR_HTML = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <style>
    body {
      font-family: -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 16px;
      line-height: 1.5;
      color: #ffffff;
      background-color: #1A1B1E;
      margin: 0;
      padding: 16px;
      height: 100vh;
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }

    .ProseMirror {
      outline: none;
      min-height: 100%;
    }

    .ProseMirror p {
      margin: 8px 0;
    }

    .ProseMirror p.is-editor-empty:first-child::before {
      content: attr(data-placeholder);
      float: left;
      color: #636366;
      pointer-events: none;
      height: 0;
    }

    .ProseMirror ul, .ProseMirror ol {
      padding: 0 0 0 20px;
    }

    .ProseMirror blockquote {
      border-left: 3px solid #eab308;
      padding-left: 12px;
      margin-left: 0;
      color: #a1a1aa;
    }

    .ProseMirror a {
      color: #eab308;
      text-decoration: underline;
    }

    /* Task Lists */
    ul[data-type="taskList"] {
      list-style: none;
      padding: 0;
    }

    ul[data-type="taskList"] li {
      display: flex;
      align-items: flex-start;
      margin-bottom: 4px;
    }

    ul[data-type="taskList"] li > label {
      flex: 0 0 auto;
      user-select: none;
      margin-right: 12px;
      margin-top: 4px;
    }

    ul[data-type="taskList"] li > div {
      flex: 1 1 auto;
    }

    input[type="checkbox"] {
      width: 18px;
      height: 18px;
      accent-color: #eab308;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/@tiptap/standalone@2.11.0/dist/index.js"></script>
</head>
<body>
  <div id="editor"></div>

  <script>
    const { Editor, StarterKit, Underline, TaskList, TaskItem, Link, Placeholder } = Tiptap;

    let isInternalUpdate = false;

    const editor = new Editor({
      element: document.querySelector('#editor'),
      extensions: [
        StarterKit,
        Underline,
        TaskList,
        TaskItem.configure({
          nested: true,
        }),
        Link.configure({
          openOnClick: false,
          autolink: true,
        }),
        Placeholder.configure({
          placeholder: 'Start writing...',
        }),
      ],
      content: '',
      onUpdate({ editor }) {
        isInternalUpdate = true;
        const html = editor.getHTML();
        if (window.ReactNativeWebView) {
          window.ReactNativeWebView.postMessage(JSON.stringify({
            type: 'onChange',
            payload: html
          }));
        }
      },
      onFocus() {
        if (window.ReactNativeWebView) {
          window.ReactNativeWebView.postMessage(JSON.stringify({
            type: 'onFocus'
          }));
        }
      },
      onBlur() {
        if (window.ReactNativeWebView) {
          window.ReactNativeWebView.postMessage(JSON.stringify({
            type: 'onBlur'
          }));
        }
      }
    });

    window.addEventListener('message', (event) => {
      try {
        const message = JSON.parse(event.data);
        if (message.type === 'setContent') {
          // If we receive setContent, we force it unless it's exactly what we already have
          const currentHtml = editor.getHTML();
          if (message.payload !== currentHtml) {
            editor.commands.setContent(message.payload, false);
          }
          isInternalUpdate = false;
        } else if (message.type === 'toggleBold') {
          editor.chain().focus().toggleBold().run();
        } else if (message.type === 'toggleItalic') {
          editor.chain().focus().toggleItalic().run();
        } else if (message.type === 'toggleStrike') {
          editor.chain().focus().toggleStrike().run();
        } else if (message.type === 'toggleBulletList') {
          editor.chain().focus().toggleBulletList().run();
        } else if (message.type === 'toggleOrderedList') {
          editor.chain().focus().toggleOrderedList().run();
        } else if (message.type === 'toggleTaskList') {
          editor.chain().focus().toggleTaskList().run();
        } else if (message.type === 'undo') {
          editor.chain().focus().undo().run();
        } else if (message.type === 'redo') {
          editor.chain().focus().redo().run();
        }
      } catch (e) {
        // Silently handle
      }
    });

    // Notify RN that we're ready
    if (window.ReactNativeWebView) {
      window.ReactNativeWebView.postMessage(JSON.stringify({
        type: 'onReady'
      }));
    }
  </script>
</body>
</html>
`;
