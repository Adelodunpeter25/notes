import { useEffect, useState, useRef, useCallback } from "react";
import { Alert, Pressable, Text, View, Keyboard, Platform } from "react-native";
import { ChevronLeft, MoreVertical } from "lucide-react-native";
import { useNavigation, useRoute, type RouteProp } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import type { AppStackParamList } from "@/navigation/types";
import { ScreenContainer } from "@/components/layout";
import { Editor, type EditorRef } from "@/components/editor";
import { NoteContextMenu } from "@/components/notes";
import { ConfirmDialog, ContextMenu, type ContextMenuItem } from "@/components/common";
import {
  useNoteQuery,
  useUpdateNoteMutation,
  useDeleteNoteMutation,
  useFoldersQuery,
  useRestoreNoteMutation,
  usePermanentlyDeleteNoteMutation,
} from "@/hooks";
import { deriveNoteTitleFromHtml, isEmptyDraftNote } from "@shared-utils/noteContent";
import type { Note } from "@shared/notes";

type EditorRoute = RouteProp<AppStackParamList, "Editor">;
type Navigation = StackNavigationProp<AppStackParamList, "Editor">;
const EDITOR_SURFACE_COLOR = "#000000";

export function NoteEditorScreen() {
  const navigation = useNavigation<Navigation>();
  const route = useRoute<EditorRoute>();
  const { noteId, note: routeNote, isTrash } = route.params;

  const notesQuery = useNoteQuery(noteId);
  const updateNoteMutation = useUpdateNoteMutation();
  const deleteNoteMutation = useDeleteNoteMutation();
  const restoreMutation = useRestoreNoteMutation();
  const permanentDeleteMutation = usePermanentlyDeleteNoteMutation();
  const foldersQuery = useFoldersQuery();

  const note = notesQuery.data;

  const [content, setContent] = useState(routeNote?.content || "");
  const prevNoteId = useRef<string | null>(null);
  const hasInitializedContent = useRef(false);
  const hasUserEdited = useRef(false);
  const lastSavedContent = useRef("");
  const lastSavedTitle = useRef("");
  const isLeavingRef = useRef(false);
  // Always-current content ref so saveNow never captures a stale closure value
  const contentRef = useRef("");
  // Holds the in-flight save promise; second caller awaits it instead of starting a new one
  const savingPromiseRef = useRef<Promise<void> | null>(null);
  const [menuAnchor, setMenuAnchor] = useState<{ x: number; y: number } | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isMoveOpen, setIsMoveOpen] = useState(false);
  const [isDeleteConfirmOpen, setIsDeleteConfirmOpen] = useState(false);
  const [isKeyboardVisible, setIsKeyboardVisible] = useState(false);
  const editorRef = useRef<EditorRef>(null);

  useEffect(() => {
    const showSub = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow",
      () => setIsKeyboardVisible(true)
    );
    const hideSub = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide",
      () => setIsKeyboardVisible(false)
    );

    return () => {
      showSub.remove();
      hideSub.remove();
    };
  }, []);

  useEffect(() => {
    if (routeNote && routeNote.id === noteId && prevNoteId.current !== noteId) {
      const initialContent = routeNote.content || "";
      setContent(initialContent);
      contentRef.current = initialContent;
      prevNoteId.current = noteId;
      hasInitializedContent.current = true;
      hasUserEdited.current = false;
      lastSavedContent.current = initialContent;
      lastSavedTitle.current = routeNote.title || "Untitled";
      savingPromiseRef.current = null;
    }
  }, [routeNote, noteId]);

  useEffect(() => {
    if (!note) {
      return;
    }

    if (note.id !== prevNoteId.current) {
      const initialContent = note.content || "";
      setContent(initialContent);
      contentRef.current = initialContent;
      prevNoteId.current = note.id;
      hasInitializedContent.current = true;
      hasUserEdited.current = false;
      lastSavedContent.current = initialContent;
      lastSavedTitle.current = note.title || "Untitled";
      savingPromiseRef.current = null;
      return;
    }

    // Keep editor hydrated when fresh DB data arrives, unless user already edited locally.
    if (!hasUserEdited.current && note.content !== contentRef.current) {
      const refreshedContent = note.content || "";
      setContent(refreshedContent);
      contentRef.current = refreshedContent;
      lastSavedContent.current = refreshedContent;
      lastSavedTitle.current = note.title || "Untitled";
    }
  }, [note]);

  const handleEditorChange = useCallback((nextContent: string) => {
    hasUserEdited.current = true;
    contentRef.current = nextContent;
    setContent(nextContent);
  }, []);

  const saveNow = useCallback(async () => {
    // If a save is already in-flight, await it instead of starting a duplicate
    if (savingPromiseRef.current) {
      return savingPromiseRef.current;
    }

    // Small delay to ensure any pending webview bridge messages are processed
    await new Promise(resolve => setTimeout(resolve, 100));

    if (!hasInitializedContent.current || !hasUserEdited.current) {
      return;
    }

    // Read from ref — always the latest content regardless of when saveNow was created
    const currentContent = contentRef.current;
    const currentNoteId = prevNoteId.current;
    if (!currentNoteId) return;

    const derivedTitle = deriveNoteTitleFromHtml(currentContent);
    const isUnchanged =
      currentContent === lastSavedContent.current && derivedTitle === lastSavedTitle.current;

    if (isUnchanged) {
      return;
    }

    const payload: { content: string; title?: string } = { content: currentContent };
    if (derivedTitle !== lastSavedTitle.current) {
      payload.title = derivedTitle;
    }

    const promise = updateNoteMutation.mutateAsync({
      noteId: currentNoteId,
      payload,
    }).then((updatedNote) => {
      lastSavedContent.current = updatedNote.content;
      lastSavedTitle.current = updatedNote.title;
    }).finally(() => {
      savingPromiseRef.current = null;
    });

    savingPromiseRef.current = promise;
    return promise;
  }, [updateNoteMutation]);

  useEffect(() => {
    const unsubscribe = navigation.addListener("beforeRemove", (event) => {
      if (isLeavingRef.current) {
        return;
      }

      event.preventDefault();
      isLeavingRef.current = true;

      const currentContent = contentRef.current;
      const derivedTitle = deriveNoteTitleFromHtml(currentContent);
      const isDraft = isEmptyDraftNote({ title: derivedTitle, content: currentContent, isPinned: note?.isPinned });

      if (isDraft && note) {
        void deleteNoteMutation.mutateAsync(note.id).finally(() => {
          navigation.dispatch(event.data.action);
        });
        return;
      }

      void saveNow().finally(() => {
        navigation.dispatch(event.data.action);
      });
    });

    return unsubscribe;
  }, [navigation, saveNow, note, deleteNoteMutation]);

  const handlePinToggle = async () => {
    if (!note) return;
    await updateNoteMutation.mutateAsync({
      noteId: note.id,
      payload: { isPinned: !note.isPinned },
    });
  };

  const handleMoveOpen = () => {
    if (!note) return;
    const availableFolders = (foldersQuery.data ?? []).filter((folder) => folder.id !== note.folderId);
    if (availableFolders.length === 0) {
      Alert.alert("No folders", "Create a folder first.");
      return;
    }
    setIsMoveOpen(true);
  };

  const handleDeleteConfirm = async () => {
    if (!note) return;
    await deleteNoteMutation.mutateAsync(note.id);
    setIsDeleteConfirmOpen(false);
    navigation.goBack();
  };

  const moveItems: (ContextMenuItem | "separator")[] = ((foldersQuery.data ?? []).filter(
    (folder) => folder.id !== note?.folderId,
  )).map((folder) => ({
    label: folder.name,
    onPress: () => {
      if (!note) return;
      void updateNoteMutation.mutateAsync({
        noteId: note.id,
        payload: { folderId: folder.id },
      });
      setIsMoveOpen(false);
      setMenuAnchor(null);
    },
  }));


  return (
    <ScreenContainer style={{ backgroundColor: EDITOR_SURFACE_COLOR }}>
      <View style={{ backgroundColor: EDITOR_SURFACE_COLOR }} className="px-2 pt-4 pb-2">
        <View className="flex-row items-center justify-between">
        <Pressable
          onPress={async () => {
            if (isLeavingRef.current) return;
            isLeavingRef.current = true;

            const currentContent = contentRef.current;
            const derivedTitle = deriveNoteTitleFromHtml(currentContent);
            const isDraft = isEmptyDraftNote({ title: derivedTitle, content: currentContent, isPinned: note?.isPinned });

            if (isDraft && note) {
              await deleteNoteMutation.mutateAsync(note.id);
            } else {
              await saveNow();
            }
            navigation.goBack();
          }}
          hitSlop={20}
          className="flex-row items-center self-start rounded-md px-2 py-1"
        >
          <ChevronLeft size={20} color="#eab308" />
          <Text className="ml-0.5 text-sm font-medium text-accent">Back</Text>
        </Pressable>
          {isTrash ? (
            <View className="flex-row items-center gap-3">
              <Pressable
                onPress={() => restoreMutation.mutate(noteId, { onSuccess: () => navigation.goBack() })}
                hitSlop={10}
              >
                <Text className="text-[15px] font-medium text-accent">Restore</Text>
              </Pressable>
              <Pressable
                onPress={() => setIsDeleteConfirmOpen(true)}
                hitSlop={10}
              >
                <Text className="text-[15px] font-medium text-red-400">Delete Forever</Text>
              </Pressable>
            </View>
          ) : (
          <View className="flex-row items-center gap-1">
            {isKeyboardVisible ? (
              <Pressable
                onPress={() => {
                  editorRef.current?.blur();
                  Keyboard.dismiss();
                  void saveNow();
                }}
                disabled={updateNoteMutation.isPending}
                className="rounded-md px-2.5 py-1.5 hover:bg-white/5 active:bg-white/10"
                hitSlop={20}
              >
                <Text className={`text-[15px] font-bold ${updateNoteMutation.isPending ? "text-accent/50" : "text-accent"}`}>
                  {updateNoteMutation.isPending ? "Saving..." : "Done"}
                </Text>
              </Pressable>
            ) : (
              <Pressable
                onPress={(event) => {
                  const { pageX, pageY } = event.nativeEvent;
                  setMenuAnchor({ x: pageX, y: pageY });
                  setIsMenuOpen(true);
                }}
                className="rounded-md p-2 hover:bg-white/5 active:bg-white/10"
                hitSlop={20}
              >
                <MoreVertical size={22} color="#eab308" />
              </Pressable>
            )}
          </View>
          )}
        </View>
      </View>

      <View className="flex-1">
        <Editor
          ref={editorRef}
          key={noteId}
          value={content}
          onChange={handleEditorChange}
          timestamp={note?.updatedAt || note?.createdAt}
          editable={!isTrash}
        />
      </View>

      <NoteContextMenu
        visible={isMenuOpen}
        note={note ?? null}
        anchor={menuAnchor}
        onClose={() => {
          setIsMenuOpen(false);
        }}
        onPin={() => {
          void handlePinToggle();
        }}
        onMove={() => {
          handleMoveOpen();
        }}
        onDelete={() => {
          setIsDeleteConfirmOpen(true);
        }}
      />

      <ContextMenu
        visible={isMoveOpen}
        anchor={menuAnchor}
        title="Move to Folder"
        items={moveItems}
        onClose={() => {
          setIsMoveOpen(false);
          setMenuAnchor(null);
        }}
      />

      <ConfirmDialog
        visible={isDeleteConfirmOpen}
        title={isTrash ? "Delete Forever?" : "Delete Note"}
        description={isTrash ? "This note will be permanently deleted. This cannot be undone." : "Are you sure you want to delete this note?"}
        confirmLabel={isTrash ? "Delete Forever" : "Delete"}
        destructive
        onConfirm={() => {
          if (isTrash) {
            permanentDeleteMutation.mutate(noteId, { onSuccess: () => { setIsDeleteConfirmOpen(false); navigation.goBack(); } });
          } else {
            void handleDeleteConfirm();
          }
        }}
        onCancel={() => setIsDeleteConfirmOpen(false)}
      />
    </ScreenContainer>
  );
}
