import { useEffect, useMemo, useRef, useState } from "react";
import { NotebookText, Search, X, ChevronUp, ChevronDown } from "lucide-react";
import type { Editor as TiptapEditor } from "@tiptap/react";
import { getCurrentWindow } from "@tauri-apps/api/window";

import type { Note } from "@shared/notes";
import { useDebounce } from "@/hooks";
import { formatNoteDateTime } from "@shared-utils/formatDate";
import { deriveNoteTitleFromHtml } from "@shared-utils/noteContent";
import { Toolbar } from "./Toolbar";
import { EditorSearchBar } from "./EditorSearchBar";
import { Editor } from "@/components/editor";
import { useUiStore } from "@/stores";

type NoteEditorProps = {
    note?: Note;
    onSave: (noteId: string, payload: { title: string; content: string; isPinned: boolean }) => Promise<unknown> | void;
    onClearSelection?: () => void;
    searchResultsOverlay?: React.ReactNode;
};

export function NoteEditor({ note, onSave, onClearSelection, searchResultsOverlay }: NoteEditorProps) {
    const [content, setContent] = useState("");
    const [isPinned, setIsPinned] = useState(false);
    const [, forceRender] = useState(0);
    const editorRef = useRef<TiptapEditor | null>(null);
    const contentContainerRef = useRef<HTMLDivElement | null>(null);

    const isEditorSearchOpen = useUiStore((state) => state.isEditorSearchOpen);
    const setIsEditorSearchOpen = useUiStore((state) => state.setIsEditorSearchOpen);
    const [findQuery, setFindQuery] = useState("");
    const findInputRef = useRef<HTMLInputElement>(null);

    // Focus find input when opened
    useEffect(() => {
        if (isEditorSearchOpen) {
            setTimeout(() => findInputRef.current?.focus(), 10);
        } else {
            setFindQuery("");
            // Clear highlights
            if (typeof window !== "undefined") {
                window.getSelection()?.removeAllRanges();
            }
        }
    }, [isEditorSearchOpen]);

    // Find in page using window.find
    function findNext(reverse = false) {
        if (!findQuery) return;
        window.find(findQuery, false, reverse, true, false, false, false);
    }

    // Close on Escape
    useEffect(() => {
        if (!isEditorSearchOpen) return;
        function onKey(e: KeyboardEvent) {
            if (e.key === "Escape") { e.stopPropagation(); setIsEditorSearchOpen(false); }
            if (e.key === "Enter") { e.preventDefault(); findNext(e.shiftKey); }
        }
        window.addEventListener("keydown", onKey, true);
        return () => window.removeEventListener("keydown", onKey, true);
    }, [isEditorSearchOpen, findQuery]);

    const debouncedContent = useDebounce(content, 200);
    const debouncedIsPinned = useDebounce(isPinned, 200);
    const initialValues = useRef({ title: "", content: "", isPinned: false });
    const activeNoteIdRef = useRef<string | null>(null);
    const isSavingRef = useRef(false);
    const hasUserEditedRef = useRef(false);
    const saveRevisionRef = useRef(0);
    const appliedRevisionRef = useRef(0);
    const skipSaveRef = useRef(false);
    // Always-current snapshot used for flush-on-switch and flush-on-unmount
    const latestValuesRef = useRef({ content: "", isPinned: false, noteId: null as string | null });
    const onSaveRef = useRef(onSave);

    const derivedTitle = useMemo(() => deriveNoteTitleFromHtml(debouncedContent), [debouncedContent]);

    const isDebounceSettled = debouncedContent === content && debouncedIsPinned === isPinned;

    // Keep onSaveRef current so flush callbacks never capture a stale onSave
    useEffect(() => {
        onSaveRef.current = onSave;
    });

    // Save on window close
    useEffect(() => {
        let unlisten: (() => void) | undefined;
        let closing = false;

        // Only register on the main window — quick-note handles its own close
        if (getCurrentWindow().label !== 'main') return;

        getCurrentWindow().onCloseRequested(async (event) => {
            if (closing) return;
            event.preventDefault();
            closing = true;
            try {
                const { content: c, isPinned: pin, noteId } = latestValuesRef.current;
                if (noteId && hasUserEditedRef.current) {
                    const title = deriveNoteTitleFromHtml(c) || "Untitled";
                    const hasChanges =
                        title !== (initialValues.current.title || "Untitled") ||
                        c !== initialValues.current.content ||
                        pin !== initialValues.current.isPinned;
                    if (hasChanges) {
                        await onSaveRef.current(noteId, { title, content: c, isPinned: pin });
                    }
                }
            } finally {
                getCurrentWindow().close();
            }
        }).then((fn) => { unlisten = fn; });

        return () => { unlisten?.(); };
    }, []);

    useEffect(() => {
        const nextNoteId = note?.id ?? null;
        if (activeNoteIdRef.current === nextNoteId) {
            return;
        }

        // Flush unsaved changes for the note we're leaving before resetting state
        const prevNoteId = activeNoteIdRef.current;
        if (prevNoteId && hasUserEditedRef.current) {
            const { content: prevContent, isPinned: prevPin } = latestValuesRef.current;
            const prevTitle = deriveNoteTitleFromHtml(prevContent) || "Untitled";
            const hasChanges =
                prevTitle !== (initialValues.current.title || "Untitled") ||
                prevContent !== initialValues.current.content ||
                prevPin !== initialValues.current.isPinned;
            if (hasChanges) {
                void onSaveRef.current(prevNoteId, { title: prevTitle, content: prevContent, isPinned: prevPin });
            }
        }

        activeNoteIdRef.current = nextNoteId;
        latestValuesRef.current = { content: note?.content ?? "", isPinned: note?.isPinned ?? false, noteId: nextNoteId };
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
        ++saveRevisionRef.current;
        const payload = { title: derivedTitle || "Untitled", content: debouncedContent, isPinned: debouncedIsPinned };

        void Promise.resolve(
            onSave(noteId, payload),
        ).then(() => {
            if (cancelled || activeNoteIdRef.current !== noteId) {
                return;
            }

            initialValues.current = payload;
        }).finally(() => {
            isSavingRef.current = false;
            // Force re-render so `hasDebouncedChanges` is evaluated again in case edits happened during save
            if (!cancelled) {
                forceRender(c => c + 1);
            }
        });

        return () => {
            cancelled = true;
            // Flush any unsaved changes that were buffered while the save was in-flight
            const { content: latestContent, isPinned: latestPin, noteId: latestNoteId } = latestValuesRef.current;
            if (!latestNoteId || !hasUserEditedRef.current) return;
            const latestTitle = deriveNoteTitleFromHtml(latestContent) || "Untitled";
            const hasUnsaved =
                latestTitle !== (initialValues.current.title || "Untitled") ||
                latestContent !== initialValues.current.content ||
                latestPin !== initialValues.current.isPinned;
            if (hasUnsaved) {
                void onSaveRef.current(latestNoteId, { title: latestTitle, content: latestContent, isPinned: latestPin });
            }
        };
    }, [derivedTitle, debouncedContent, debouncedIsPinned, hasDebouncedChanges, note?.id, onSave]);

    const noteDateLabel = formatNoteDateTime(note?.updatedAt || note?.createdAt);

    return (
        <div className="flex h-full flex-col bg-background">
            <Toolbar
                editor={editorRef.current}
                isPinned={isPinned}
                onTogglePin={() => {
                    const next = !isPinned;
                    latestValuesRef.current = { ...latestValuesRef.current, isPinned: next };
                    setIsPinned(next);
                }}
                showFormatting={!!note && !searchResultsOverlay}
            />
            <EditorSearchBar />

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
                            latestValuesRef.current = { ...latestValuesRef.current, content: value };
                            setContent(value);
                        }}
                        editorRef={editorRef}
                    />
                </div>
            )}
        </div>
    );
}
