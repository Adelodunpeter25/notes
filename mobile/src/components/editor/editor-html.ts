export const TIPTAP_EDITOR_HTML = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <style>
    body {
      font-family: -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 14px;
      line-height: 1.55;
      color: #ffffff;
      background-color: #000000;
      margin: 0;
      padding: 16px;
      min-height: 100vh;
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }

    #editor {
      min-height: calc(100vh - 32px);
    }

    .ProseMirror {
      outline: none;
      min-height: calc(100vh - 32px);
      word-break: break-word;
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

    /* Apple Notes-ish typography */
    .ProseMirror h1 {
      font-size: 26px;
      font-weight: 700;
      line-height: 1.25;
      margin: 8px 0 4px;
      letter-spacing: -0.3px;
    }
    .ProseMirror h2 {
      font-size: 20px;
      font-weight: 600;
      line-height: 1.3;
      margin: 12px 0 2px;
    }
    .ProseMirror h3 {
      font-size: 14px;
      font-weight: 600;
      line-height: 1.4;
      margin: 8px 0 2px;
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

    .ProseMirror code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      font-size: 14px;
      background: rgba(255,255,255,0.06);
      padding: 1px 5px;
      border-radius: 4px;
      color: #ffffff;
    }

    .ProseMirror pre {
      background: rgba(255,255,255,0.06);
      border-radius: 10px;
      padding: 12px 14px;
      overflow-x: auto;
      margin: 10px 0;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      font-size: 14px;
      line-height: 1.5;
    }
    .ProseMirror pre code {
      background: none;
      padding: 0;
      font-size: inherit;
    }

    .ProseMirror hr {
      border: none;
      border-top: 1px solid rgba(255,255,255,0.10);
      margin: 14px 0;
    }

    /* Indent (custom attr) */
    .ProseMirror [data-indent="1"] { margin-left: 24px; }
    .ProseMirror [data-indent="2"] { margin-left: 48px; }
    .ProseMirror [data-indent="3"] { margin-left: 72px; }
    .ProseMirror [data-indent="4"] { margin-left: 96px; }
    .ProseMirror [data-indent="5"] { margin-left: 120px; }
    .ProseMirror [data-indent="6"] { margin-left: 144px; }

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
</head>
<body>
  <div id="editor"></div>

  <script type="module">
    const rnLog = (msg) => {
      try {
        if (window.ReactNativeWebView) {
          window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'log', payload: msg }));
        }
      } catch (e) {}
    };

    rnLog('[WebView] Starting Tiptap initialization...');
    
    try {
      Promise.all([
        import('https://esm.sh/@tiptap/core@2.11.0'),
        import('https://esm.sh/@tiptap/extension-document@2.11.0'),
        import('https://esm.sh/@tiptap/extension-paragraph@2.11.0'),
        import('https://esm.sh/@tiptap/extension-text@2.11.0'),
        import('https://esm.sh/@tiptap/extension-bold@2.11.0'),
        import('https://esm.sh/@tiptap/extension-italic@2.11.0'),
        import('https://esm.sh/@tiptap/extension-underline@2.11.0'),
        import('https://esm.sh/@tiptap/extension-strike@2.11.0'),
        import('https://esm.sh/@tiptap/extension-code@2.11.0'),
        import('https://esm.sh/@tiptap/extension-code-block@2.11.0'),
        import('https://esm.sh/@tiptap/extension-heading@2.11.0'),
        import('https://esm.sh/@tiptap/extension-bullet-list@2.11.0'),
        import('https://esm.sh/@tiptap/extension-ordered-list@2.11.0'),
        import('https://esm.sh/@tiptap/extension-list-item@2.11.0'),
        import('https://esm.sh/@tiptap/extension-task-list@2.11.0'),
        import('https://esm.sh/@tiptap/extension-task-item@2.11.0'),
        import('https://esm.sh/@tiptap/extension-text-align@2.11.0'),
        import('https://esm.sh/@tiptap/extension-history@2.11.0'),
        import('https://esm.sh/@tiptap/extension-placeholder@2.11.0'),
        import('https://esm.sh/@tiptap/extension-horizontal-rule@2.11.0'),
        import('https://esm.sh/@tiptap/extension-blockquote@2.11.0'),
        import('https://esm.sh/@tiptap/extension-link@2.11.0'),
      ]).then(([
        { Editor, Extension },
        { default: Document },
        { default: Paragraph },
        { default: Text },
        { default: Bold },
        { default: Italic },
        { default: Underline },
        { default: Strike },
        { default: Code },
        { default: CodeBlock },
        { default: Heading },
        { default: BulletList },
        { default: OrderedList },
        { default: ListItem },
        { default: TaskList },
        { default: TaskItem },
        { default: TextAlign },
        { default: History },
        { default: Placeholder },
        { default: HorizontalRule },
        { default: Blockquote },
        { default: Link },
      ]) => {
        rnLog('[WebView] Tiptap modules loaded successfully');

        const Indent = Extension.create({
          name: 'indent',
          addOptions() {
            return { minIndent: 0, maxIndent: 6 };
          },
          addGlobalAttributes() {
            return [{
              types: ['paragraph', 'heading', 'listItem', 'taskItem'],
              attributes: {
                indent: {
                  default: 0,
                  renderHTML: attrs => attrs.indent > 0 ? { 'data-indent': attrs.indent } : {},
                  parseHTML: el => parseInt(el.getAttribute('data-indent') || '0', 10),
                }
              }
            }];
          },
          addCommands() {
            return {
              indent: () => ({ tr, state, dispatch }) => {
                const { from, to } = state.selection;
                let changed = false;
                state.doc.nodesBetween(from, to, (node, pos) => {
                  if (['paragraph', 'heading', 'listItem', 'taskItem'].includes(node.type.name)) {
                    const cur = node.attrs.indent || 0;
                    if (cur < 6) {
                      tr.setNodeMarkup(pos, null, { ...node.attrs, indent: cur + 1 });
                      changed = true;
                    }
                  }
                });
                if (changed && dispatch) dispatch(tr);
                return changed;
              },
              outdent: () => ({ tr, state, dispatch }) => {
                const { from, to } = state.selection;
                let changed = false;
                state.doc.nodesBetween(from, to, (node, pos) => {
                  if (['paragraph', 'heading', 'listItem', 'taskItem'].includes(node.type.name)) {
                    const cur = node.attrs.indent || 0;
                    if (cur > 0) {
                      tr.setNodeMarkup(pos, null, { ...node.attrs, indent: cur - 1 });
                      changed = true;
                    }
                  }
                });
                if (changed && dispatch) dispatch(tr);
                return changed;
              }
            };
          },
        });

        const editor = new Editor({
          element: document.querySelector('#editor'),
          extensions: [
            Document,
            Paragraph,
            Text,
            Bold,
            Italic,
            Underline,
            Strike,
            Code,
            CodeBlock,
            Heading.configure({ levels: [1, 2, 3] }),
            BulletList,
            OrderedList,
            ListItem,
            TaskList,
            TaskItem.configure({ nested: true }),
            TextAlign.configure({ types: ['heading', 'paragraph'] }),
            Indent,
            History,
            HorizontalRule,
            Blockquote,
            Link.configure({ openOnClick: false, autolink: true }),
            Placeholder.configure({ placeholder: 'Start writing...' }),
          ],
          content: '',
          onUpdate({ editor }) {
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

        window.editor = editor;

          // Expose global function for highly reliable RN direct injections
          window.rnUpdateContent = function(htmlContent) {
            try {
              rnLog('[WebView] rnUpdateContent called, content length: ' + (htmlContent ? htmlContent.length : 0));
              const currentHtml = editor.getHTML();
              if (htmlContent !== currentHtml) {
                editor.commands.setContent(htmlContent, false);
              }
            } catch (e) {
              rnLog('[WebView] rnUpdateContent Error: ' + e.message);
            }
          };

          window.addEventListener('message', (event) => {
            try {
              const message = JSON.parse(event.data);
              rnLog('[WebView] Received message: ' + message.type);
              
              if (message.type === 'setContent') {
                window.rnUpdateContent(message.payload);
              } else if (message.type === 'toggleBold') {
                editor.chain().focus().toggleBold().run();
              } else if (message.type === 'toggleItalic') {
                editor.chain().focus().toggleItalic().run();
              } else if (message.type === 'toggleUnderline') {
                editor.chain().focus().toggleUnderline().run();
              } else if (message.type === 'toggleStrike') {
                editor.chain().focus().toggleStrike().run();
              } else if (message.type === 'toggleCode') {
                editor.chain().focus().toggleCode().run();
              } else if (message.type === 'toggleCodeBlock') {
                editor.chain().focus().toggleCodeBlock().run();
              } else if (message.type === 'toggleBlockquote') {
                editor.chain().focus().toggleBlockquote().run();
              } else if (message.type === 'toggleBulletList') {
                editor.chain().focus().toggleBulletList().run();
              } else if (message.type === 'toggleOrderedList') {
                editor.chain().focus().toggleOrderedList().run();
              } else if (message.type === 'toggleTaskList') {
                editor.chain().focus().toggleTaskList().run();
              } else if (message.type === 'setHeading') {
                const level = Number(message?.payload?.level);
                if (level === 1 || level === 2 || level === 3) {
                  editor.chain().focus().setHeading({ level }).run();
                }
              } else if (message.type === 'setParagraph') {
                editor.chain().focus().setParagraph().run();
              } else if (message.type === 'setTextAlign') {
                const align = message?.payload?.align;
                if (align === 'left' || align === 'center' || align === 'right' || align === 'justify') {
                  editor.chain().focus().setTextAlign(align).run();
                }
              } else if (message.type === 'indent') {
                editor.chain().focus().indent().run();
              } else if (message.type === 'outdent') {
                editor.chain().focus().outdent().run();
              } else if (message.type === 'insertHorizontalRule') {
                editor.chain().focus().setHorizontalRule().run();
              } else if (message.type === 'undo') {
                editor.chain().focus().undo().run();
              } else if (message.type === 'redo') {
                editor.chain().focus().redo().run();
              }
            } catch (e) {
              rnLog('[WebView] JS Message Error: ' + e.message);
            }
          });

          // Fallback for some Android RN versions
          document.addEventListener('message', (event) => {
            try {
              const message = JSON.parse(event.data);
              if (message.type === 'setContent') {
                 window.rnUpdateContent(message.payload);
              }
            } catch (e) {}
          });

          rnLog('[WebView] Editor initialized, sending onReady');
          if (window.ReactNativeWebView) {
            window.ReactNativeWebView.postMessage(JSON.stringify({
              type: 'onReady'
            }));
          }
        }).catch(err => {
          rnLog('[WebView] Module load error: ' + err.message);
        });
    } catch (err) {
      rnLog('[WebView] Init error: ' + err.message);
    }
  </script>
</body>
</html>
`;
