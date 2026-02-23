export const getTiptapHtml = (initialContent: string) => `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <title>Tiptap Editor</title>
    <script src="https://unpkg.com/@tiptap/standalone@2.2.4/dist/index.js"></script>
    <style>
        body {
            margin: 0;
            padding: 16px;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #1e1e1e;
            color: #ffffff;
            min-height: 100vh;
        }

        .ProseMirror {
            outline: none;
            min-height: 200px;
            font-size: 16px;
            line-height: 1.6;
            color: rgba(255, 255, 255, 0.9);
        }

        .ProseMirror p.is-editor-empty:first-child::before {
            content: attr(data-placeholder);
            float: left;
            color: #636366;
            pointer-events: none;
            height: 0;
        }

        .ProseMirror a {
            color: #eab308;
            text-decoration: underline;
            text-underline-offset: 2px;
        }

        .ProseMirror ul, .ProseMirror ol {
            padding-left: 20px;
        }

        .ProseMirror li {
            margin-bottom: 4px;
        }

        .ProseMirror blockquote {
            border-left: 3px solid #3e3e3e;
            padding-left: 16px;
            margin-left: 0;
            color: #a0a0a0;
        }

        .ProseMirror code {
            background-color: #2b2b2b;
            padding: 2px 4px;
            border-radius: 4px;
            font-family: monospace;
        }

        .ProseMirror pre {
            background-color: #2b2b2b;
            padding: 12px;
            border-radius: 8px;
            overflow-x: auto;
        }

        .ProseMirror pre code {
            background-color: transparent;
            padding: 0;
        }

        ul[data-type="taskList"] {
            list-style: none;
            padding: 0;
        }

        ul[data-type="taskList"] li {
            display: flex;
            align-items: flex-start;
            margin-bottom: 8px;
        }

        ul[data-type="taskList"] li > label {
            margin-right: 12px;
            user-select: none;
        }

        ul[data-type="taskList"] li > div {
            flex: 1;
        }

        input[type="checkbox"] {
            appearance: none;
            width: 20px;
            height: 20px;
            border: 2px solid #3e3e3e;
            border-radius: 6px;
            background-color: transparent;
            cursor: pointer;
            position: relative;
            margin-top: 2px;
        }

        input[type="checkbox"]:checked {
            background-color: #eab308;
            border-color: #eab308;
        }

        input[type="checkbox"]:checked::after {
            content: "✓";
            position: absolute;
            color: black;
            font-size: 14px;
            font-weight: bold;
            left: 3px;
            top: -1px;
        }
    </style>
</head>
<body>
    <div id="editor"></div>

    <script>
        const { Editor, StarterKit, Underline, TaskList, TaskItem, Placeholder, Link } = Tiptap;

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
                    autolink: true,
                    openOnClick: false,
                    HTMLAttributes: {
                        class: 'editor-link',
                    },
                }),
                Placeholder.configure({
                    placeholder: 'Start writing...',
                }),
            ],
            content: \`${initialContent}\`,
            onUpdate: ({ editor }) => {
                const html = editor.getHTML();
                window.ReactNativeWebView.postMessage(JSON.stringify({
                    type: 'UPDATE',
                    content: html
                }));
            },
            onFocus: () => {
                window.ReactNativeWebView.postMessage(JSON.stringify({
                    type: 'FOCUS'
                }));
            }
        });

        window.addEventListener('message', (event) => {
            try {
                const message = JSON.parse(event.data);
                if (message.type === 'SET_CONTENT') {
                    editor.commands.setContent(message.content, false);
                } else if (message.type === 'TOGGLE_BOLD') {
                    editor.chain().focus().toggleBold().run();
                } else if (message.type === 'TOGGLE_ITALIC') {
                    editor.chain().focus().toggleItalic().run();
                } else if (message.type === 'TOGGLE_STRIKE') {
                    editor.chain().focus().toggleStrike().run();
                } else if (message.type === 'TOGGLE_BULLET_LIST') {
                    editor.chain().focus().toggleBulletList().run();
                } else if (message.type === 'TOGGLE_ORDERED_LIST') {
                    editor.chain().focus().toggleOrderedList().run();
                } else if (message.type === 'TOGGLE_TASK_LIST') {
                    editor.chain().focus().toggleTaskList().run();
                }
            } catch (e) {
                // Ignore parsing errors from other sources
            }
        });

        // Notify that the editor is ready
        window.ReactNativeWebView.postMessage(JSON.stringify({
            type: 'READY'
        }));
    </script>
</body>
</html>
`;
