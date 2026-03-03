import { useEffect, useMemo, useRef, useState } from "react";
import { NotebookText } from "lucide-react";
import type { Editor as TiptapEditor } from "@tiptap/react";

import type { Note } from "@shared/notes";
import { useDebounce, useNoteRealtime } from "@/hooks";
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

    const debouncedContent = useDebounce(content, 80);
    const debouncedIsPinned = useDebounce(isPinned, 80);
    const { isReady: isRealtimeReady, sendPatch: sendRealtimePatch } = useNoteRealtime(note?.id);
    const initialValues = useRef({ title: "", content: "", isPinned: false });
    const activeNoteIdRef = useRef<string | null>(null);
    const isSavingRef = useRef(false);

    const derivedTitle = useMemo(() => deriveNoteTitleFromHtml(debouncedContent), [debouncedContent]);

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
        isSavingRef.current = false;
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
        return (
            (derivedTitle || "Untitled") !== (initialValues.current.title || "Untitled") ||
            debouncedContent !== initialValues.current.content ||
            debouncedIsPinned !== initialValues.current.isPinned
        );
    }, [debouncedContent, debouncedIsPinned, derivedTitle, isDebounceSettled, note]);

    const latestStateRef = useRef({ noteId: note?.id, title: derivedTitle, content: debouncedContent, isPinned: debouncedIsPinned });
    useEffect(() => {
        latestStateRef.current = { noteId: note?.id, title: derivedTitle, content: debouncedContent, isPinned: debouncedIsPinned };
    }, [note?.id, derivedTitle, debouncedContent, debouncedIsPinned]);

    const callbacksRef = useRef({ onLocalSave, onSave, sendRealtimePatch, isRealtimeReady });
    useEffect(() => {
        callbacksRef.current = { onLocalSave, onSave, sendRealtimePatch, isRealtimeReady };
    }, [onLocalSave, onSave, sendRealtimePatch, isRealtimeReady]);

    useEffect(() => {
        return () => {
            const state = latestStateRef.current;
            const noteId = state.noteId;
            if (!noteId) return;

            const hasUnsavedChanges =
                (state.title || "Untitled") !== (initialValues.current.title || "Untitled") ||
                state.content !== initialValues.current.content ||
                state.isPinned !== initialValues.current.isPinned;

            if (hasUnsavedChanges && !isSavingRef.current) {
                const payload = { title: state.title || "Untitled", content: state.content, isPinned: state.isPinned };
                const cb = callbacksRef.current;
                cb.onLocalSave?.(noteId, payload);
                if (cb.isRealtimeReady) {
                    void cb.sendRealtimePatch(payload);
                } else {
                    void Promise.resolve(cb.onSave(noteId, payload));
                }
            }
        };
    }, []);

    useEffect(() => {
        const noteId = note?.id;
        if (!hasDebouncedChanges || !noteId || isSavingRef.current) return;
        let cancelled = false;
        isSavingRef.current = true;
        const payload = { title: derivedTitle || "Untitled", content: debouncedContent, isPinned: debouncedIsPinned };
        onLocalSave?.(noteId, payload);

        if (isRealtimeReady) {
            void sendRealtimePatch(payload)
                .catch(() => Promise.resolve(onSave(noteId, payload)))
                .then(() => {
                    if (cancelled || activeNoteIdRef.current !== noteId) {
                        return;
                    }

                    initialValues.current = payload;
                })
                .finally(() => {
                    isSavingRef.current = false;
                });
            return () => {
                cancelled = true;
            };
        }

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
    }, [derivedTitle, debouncedContent, debouncedIsPinned, hasDebouncedChanges, isRealtimeReady, note?.id, onLocalSave, onSave, sendRealtimePatch]);

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
                        onChange={setContent}
                        editorRef={editorRef}
                    />
                </div>
            )}
        </div>
    );
}
