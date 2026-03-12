import { useEffect, useMemo, useRef, useState } from "react";
import { NotebookText } from "lucide-react";
import type { Editor as TiptapEditor } from "@tiptap/react";

import type { Note } from "@shared/notes";
import { useDebounce } from "@/hooks";
import { formatNoteDateTime } from "@/utils/formatDate";
import { deriveNoteTitleFromHtml } from "@/utils/noteContent";
import { Toolbar } from "./Toolbar";
import { Editor } from "@/components/editor";

type NoteEditorProps = {
    note?: Note;
    onSave: (noteId: string, payload: { title: string; content: string; isPinned: boolean }) => Promise<unknown> | void;
    onLocalSave?: (noteId: string, payload: { title: string; content: string; isPinned: boolean }) => void;
    onClearSelection?: () => void;
    searchResultsOverlay?: React.ReactNode;
};

export function NoteEditor({ note, onSave, onLocalSave, onClearSelection, searchResultsOverlay }: NoteEditorProps) {
    const [content, setContent] = useState("");
    const [isPinned, setIsPinned] = useState(false);
    const editorRef = useRef<TiptapEditor | null>(null);
    const contentContainerRef = useRef<HTMLDivElement | null>(null);

    const debouncedContent = useDebounce(content, 50);
    const debouncedIsPinned = useDebounce(isPinned, 50);
    const initialValues = useRef({ title: "", content: "", isPinned: false });
    const activeNoteIdRef = useRef<string | null>(null);
    const isSavingRef = useRef(false);
    const hasUserEditedRef = useRef(false);
    const saveRevisionRef = useRef(0);
    const appliedRevisionRef = useRef(0);
    const skipSaveRef = useRef(false);

    const derivedTitle = useMemo(() => deriveNoteTitleFromHtml(debouncedContent), [debouncedContent]);

    const isDebounceSettled = debouncedContent === content && debouncedIsPinned === isPinned;

    useEffect(() => {
        const nextNoteId = note?.id ?? null;
        if (activeNoteIdRef.current === nextNoteId) {
            return;
        }

        activeNoteIdRef.current = nextNoteId;
        skipSaveRef.current = true;
        setContent(note?.content ?? "");
        setIsPinned(note?.isPinned ?? false);
        initialValues.current = {
            title: note?.title ?? "",
            content: note?.content ?? "",
            isPinned: note?.isPinned ?? false,
        };
        isSavingRef.current = false;
        hasUserEditedRef.current = false;
        saveRevisionRef.current = 0;
        appliedRevisionRef.current = 0;
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

    useEffect(() => {
        if (!note || searchResultsOverlay) {
            return;
        }

        const frame = window.requestAnimationFrame(() => {
            contentContainerRef.current?.scrollTo({ top: 0, behavior: "auto" });
        });

        return () => {
            window.cancelAnimationFrame(frame);
        };
    }, [note?.id, searchResultsOverlay]);

    const hasDebouncedChanges = useMemo(() => {
        if (!note || !isDebounceSettled) return false;

        const hasPinChanged = debouncedIsPinned !== initialValues.current.isPinned;
        if (hasPinChanged) {
            return true;
        }

        if (!hasUserEditedRef.current) {
            return false;
        }

        return (
            (derivedTitle || "Untitled") !== (initialValues.current.title || "Untitled") ||
            debouncedContent !== initialValues.current.content ||
            debouncedIsPinned !== initialValues.current.isPinned
        );
    }, [debouncedContent, debouncedIsPinned, derivedTitle, isDebounceSettled, note]);

    useEffect(() => {
        const noteId = note?.id;
        if (skipSaveRef.current) {
            skipSaveRef.current = false;
            return;
        }
        if (!hasDebouncedChanges || !noteId || isSavingRef.current) return;
        let cancelled = false;
        isSavingRef.current = true;
        const revision = ++saveRevisionRef.current;
        const payload = { title: derivedTitle || "Untitled", content: debouncedContent, isPinned: debouncedIsPinned };
        onLocalSave?.(noteId, payload);

        void Promise.resolve(
            onSave(noteId, payload),
        ).then(() => {
            if (cancelled || activeNoteIdRef.current !== noteId) {
                return;
            }

            initialValues.current = payload;
        }).finally(() => {
            isSavingRef.current = false;
        });

        return () => {
            cancelled = true;
        };
    }, [derivedTitle, debouncedContent, debouncedIsPinned, hasDebouncedChanges, note?.id, onLocalSave, onSave]);

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
                <div
                    ref={contentContainerRef}
                    className="min-h-0 flex-1 overflow-y-auto px-10 py-5 max-w-4xl mx-auto w-full pb-24"
                >
                    <p className="mb-3 text-center text-[11px] font-normal leading-none text-muted/70">{noteDateLabel}</p>

                    <Editor
                        content={content}
                        onChange={(value) => {
                            hasUserEditedRef.current = true;
                            setContent(value);
                        }}
                        editorRef={editorRef}
                    />
                </div>
            )}
        </div>
    );
}
