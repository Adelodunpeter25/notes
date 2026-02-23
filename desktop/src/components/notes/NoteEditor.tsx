import { useEffect, useMemo, useRef, useState } from "react";
import { NotebookText } from "lucide-react";
import type { Editor as TiptapEditor } from "@tiptap/react";

import type { Note } from "@shared/notes";
import { useDebounce } from "@/hooks";
import { formatNoteDateTime } from "@/utils/formatDate";
import { Toolbar } from "./Toolbar";
import { Editor } from "@/components/editor";

type NoteEditorProps = {
    note?: Note;
    onSave: (payload: { title: string; content: string; isPinned: boolean }) => Promise<unknown> | void;
    onClearSelection?: () => void;
    searchResultsOverlay?: React.ReactNode;
};

export function NoteEditor({ note, onSave, onClearSelection, searchResultsOverlay }: NoteEditorProps) {
    const [content, setContent] = useState("");
    const [isPinned, setIsPinned] = useState(false);
    const editorRef = useRef<TiptapEditor | null>(null);

    // Force re-render of Toolbar when editor updates state
    const [, setEditorStateTick] = useState(0);
    useEffect(() => {
        if (!editorRef.current) return;
        const editor = editorRef.current;

        // We listen to the editor transaction to trigger a React re-render of this top level component,
        // so the Toolbar buttons correctly update their "active" state when text is bolded.
        const handleUpdate = () => setEditorStateTick(t => t + 1);
        editor.on('transaction', handleUpdate);
        return () => {
            editor.off('transaction', handleUpdate);
        };
    }, [editorRef.current]);

    const debouncedContent = useDebounce(content, 500);
    const debouncedIsPinned = useDebounce(isPinned, 500);
    const initialValues = useRef({ title: "", content: "", isPinned: false });
    const activeNoteIdRef = useRef<string | null>(null);

    const derivedTitle = useMemo(() => {
        if (!debouncedContent) return "";
        const doc = new DOMParser().parseFromString(debouncedContent, "text/html");
        const blockElements = doc.querySelectorAll("p, h1, h2, h3, h4, h5, h6, li, blockquote, code");
        for (const el of Array.from(blockElements)) {
            const text = el.textContent?.trim();
            if (text) return text;
        }
        return "";
    }, [debouncedContent]);

    const isDebounceSettled = debouncedContent === content && debouncedIsPinned === isPinned;

    useEffect(() => {
        const nextNoteId = note?.id ?? null;
        if (activeNoteIdRef.current === nextNoteId) {
            return;
        }

        activeNoteIdRef.current = nextNoteId;
        setContent(note?.content ?? "");
        setIsPinned(note?.isPinned ?? false);
        initialValues.current = {
            title: note?.title ?? "",
            content: note?.content ?? "",
            isPinned: note?.isPinned ?? false,
        };
    }, [note?.id]);

    useEffect(() => {
        function handleEscapeKey(event: KeyboardEvent) {
            if (event.key !== "Escape" || !note || !onClearSelection) {
                return;
            }

            onClearSelection();
        }

        window.addEventListener("keydown", handleEscapeKey);
        return () => {
            window.removeEventListener("keydown", handleEscapeKey);
        };
    }, [note, onClearSelection]);

    const hasDebouncedChanges = useMemo(() => {
        if (!note || !isDebounceSettled) return false;
        return (
            (derivedTitle || "Untitled") !== (initialValues.current.title || "Untitled") ||
            debouncedContent !== initialValues.current.content ||
            debouncedIsPinned !== initialValues.current.isPinned
        );
    }, [debouncedContent, debouncedIsPinned, derivedTitle, isDebounceSettled, note]);

    useEffect(() => {
        if (!hasDebouncedChanges || !note) return;
        const timer = setTimeout(() => {
            void Promise.resolve(
                onSave({ title: derivedTitle || "Untitled", content: debouncedContent, isPinned: debouncedIsPinned }),
            ).then(() => {
                if (activeNoteIdRef.current !== note.id) {
                    return;
                }

                initialValues.current = {
                    title: derivedTitle || "Untitled",
                    content: debouncedContent,
                    isPinned: debouncedIsPinned,
                };
            });
        }, 500);
        return () => clearTimeout(timer);
    }, [derivedTitle, debouncedContent, debouncedIsPinned, hasDebouncedChanges, note, onSave]);

    const noteDateLabel = formatNoteDateTime(note?.updatedAt || note?.createdAt);

    return (
        <div className="flex h-full flex-col bg-background">
            <Toolbar
                editor={editorRef.current}
                isPinned={isPinned}
                onTogglePin={() => setIsPinned(!isPinned)}
                showFormatting={!!note && !searchResultsOverlay}
            />

            {searchResultsOverlay ? (
                <div className="flex-1 overflow-hidden">
                    {searchResultsOverlay}
                </div>
            ) : !note ? (
                <div className="flex-1 bg-background flex flex-col items-center justify-center p-3">
                    <div className="flex flex-col items-center justify-center gap-2 text-center select-none">
                        <div className="flex size-8 items-center justify-center rounded-full text-muted">
                            <NotebookText size={16} />
                        </div>
                        <p className="text-sm font-medium text-muted">Select a note</p>
                    </div>
                </div>
            ) : (
                <div className="min-h-0 flex-1 overflow-y-auto px-10 py-6 max-w-4xl mx-auto w-full pb-24">
                    <p className="text-center text-xs text-muted mb-6 font-medium">{noteDateLabel}</p>

                    <Editor
                        content={content}
                        onChange={setContent}
                        editorRef={editorRef}
                    />
                </div>
            )}
        </div>
    );
}
