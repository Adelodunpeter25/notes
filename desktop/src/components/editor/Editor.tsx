import { useEffect, useRef } from "react";
import { open } from "@tauri-apps/plugin-shell";
import { useEditor, EditorContent, type Editor as TiptapEditor } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Underline from "@tiptap/extension-underline";
import TaskList from "@tiptap/extension-task-list";
import TaskItem from "@tiptap/extension-task-item";
import { Table } from "@tiptap/extension-table";
import { TableRow } from "@tiptap/extension-table-row";
import { TableHeader } from "@tiptap/extension-table-header";
import { TableCell } from "@tiptap/extension-table-cell";
import Placeholder from "@tiptap/extension-placeholder";
import Link from "@tiptap/extension-link";

type EditorProps = {
    content: string;
    onChange: (value: string) => void;
    editorRef?: React.MutableRefObject<TiptapEditor | null>;
};

export function Editor({ content, onChange, editorRef }: EditorProps) {
    // Use a ref to track if the update came from internal typing or external prop change
    const isInternalUpdate = useRef(false);

    function normalizeLinkHtml(value: string): string {
        const doc = new DOMParser().parseFromString(value || "<p></p>", "text/html");
        const anchors = Array.from(doc.querySelectorAll("a"));

        anchors.forEach((anchor) => {
            const rawHref = (anchor.getAttribute("href") || "").trim();
            const rawText = (anchor.textContent || "").trim();

            let nextHref = rawHref;
            if (!nextHref && /^www\./i.test(rawText)) {
                nextHref = `https://${rawText}`;
            } else if (!nextHref && /^(https?:\/\/)/i.test(rawText)) {
                nextHref = rawText;
            } else if (nextHref && /^www\./i.test(nextHref)) {
                nextHref = `https://${nextHref}`;
            }

            if (nextHref) {
                anchor.setAttribute("href", nextHref);
            }

            anchor.setAttribute("class", "editor-link underline underline-offset-2");
            anchor.setAttribute("target", "_blank");
            anchor.setAttribute("rel", "noopener noreferrer");
        });

        return doc.body.innerHTML || "<p></p>";
    }

    const editor = useEditor({
        extensions: [
            StarterKit,
            Underline,
            TaskList,
            TaskItem.configure({
                nested: true,
            }),
            Table.configure({
                resizable: true,
            }),
            TableRow,
            TableHeader,
            TableCell,
            Link.configure({
                autolink: true,
                linkOnPaste: true,
                openOnClick: false,
                HTMLAttributes: {
                    class: "editor-link underline underline-offset-2",
                    rel: "noopener noreferrer",
                    target: "_blank",
                },
            }),
            Placeholder.configure({
                placeholder: "Write your note here...",
            }),
        ],
        content,
        onUpdate: ({ editor }) => {
            isInternalUpdate.current = true;
            onChange(normalizeLinkHtml(editor.getHTML()));
        },
        editorProps: {
            handleDOMEvents: {
                paste: (view, event) => {
                    const text = event.clipboardData?.getData("text/plain")?.trim();
                    if (!text) return false;

                    let isUrl = false;
                    try {
                        const parsed = new URL(/^www\./i.test(text) ? `https://${text}` : text);
                        isUrl = ['http:', 'https:'].includes(parsed.protocol) && parsed.hostname.includes('.');
                    } catch {
                        isUrl = false;
                    }

                    if (isUrl) {
                        event.preventDefault();
                        const href = /^www\./i.test(text) ? `https://${text}` : text;
                        const { state, dispatch } = view;
                        const mark = state.schema.marks.link.create({ href });
                        const tr = state.tr.replaceSelectionWith(state.schema.text(text, [mark]), false);
                        dispatch(tr);
                        return true;
                    }
                    return false;
                },
                click: (_view, event) => {
                    const mouseEvent = event as MouseEvent;

                    const target = mouseEvent.target as Node | null;
                    const element =
                        target instanceof Element
                            ? target
                            : (target?.parentElement ?? null);
                    const anchor = element?.closest("a[href]") as HTMLAnchorElement | null;
                    const href = (anchor?.getAttribute("href") || "").trim();

                    if (!anchor || !href) {
                        return false;
                    }

                    const isModifierPressed = mouseEvent.metaKey || mouseEvent.ctrlKey;
                    if (!isModifierPressed) {
                        // Prevent the browser from natively opening the href on regular clicks
                        mouseEvent.preventDefault();
                        return false;
                    }

                    mouseEvent.preventDefault();
                    mouseEvent.stopPropagation();
                    const normalizedHref = /^www\./i.test(href) ? `https://${href}` : href;
                    open(normalizedHref).catch(console.error);
                    return true;
                },
            },
            attributes: {
                class: "prose prose-invert max-w-none focus:outline-none min-h-[500px]",
            },
        },
    });

    useEffect(() => {
        if (editorRef) {
            editorRef.current = editor;
        }
    }, [editor, editorRef]);

    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.metaKey || e.ctrlKey) {
                document.body.classList.add('editor-modifier-active');
            }
        };

        const handleKeyUp = (e: KeyboardEvent) => {
            if (!e.metaKey && !e.ctrlKey) {
                document.body.classList.remove('editor-modifier-active');
            }
        };

        // Also remove class when window loses focus
        const handleBlur = () => {
            document.body.classList.remove('editor-modifier-active');
        };

        window.addEventListener('keydown', handleKeyDown);
        window.addEventListener('keyup', handleKeyUp);
        window.addEventListener('blur', handleBlur);

        return () => {
            window.removeEventListener('keydown', handleKeyDown);
            window.removeEventListener('keyup', handleKeyUp);
            window.removeEventListener('blur', handleBlur);
            document.body.classList.remove('editor-modifier-active');
        };
    }, []);

    useEffect(() => {
        if (editor && content !== undefined) {
            // Only set content if it wasn't an internal update (prevents cursor jumping)
            if (isInternalUpdate.current) {
                isInternalUpdate.current = false;
                return;
            }

            const currentHTML = editor.getHTML();
            const normalizedIncomingContent = normalizeLinkHtml(content || "<p></p>");
            // Inject whenever parent content differs (including empty -> non-empty transitions)
            if (normalizedIncomingContent !== currentHTML) {
                editor.commands.setContent(normalizedIncomingContent, { emitUpdate: false });
            }
        }
    }, [content, editor]);

    if (!editor) {
        return null;
    }

    return <EditorContent editor={editor} className="h-full w-full text-[14px] text-text/90 leading-relaxed" />;
}
