import { useEffect, useMemo, useState, useRef, useCallback } from "react";
import { Alert, Pressable, Text, View } from "react-native";
import { ChevronLeft, EllipsisVertical } from "lucide-react-native";
import { useNavigation, useRoute, type RouteProp } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { useQueryClient } from "@tanstack/react-query";

import type { AppStackParamList } from "@/navigation/types";
import { ScreenContainer } from "@/components/layout";
import { Editor } from "@/components/editor";
import { NoteContextMenu } from "@/components/notes";
import { ConfirmDialog, ContextMenu, type ContextMenuItem } from "@/components/common";
import {
  useDebounce,
  useNotesQuery,
  useUpdateNoteMutation,
  useDeleteNoteMutation,
  useFoldersQuery,
} from "@/hooks";
import { notesKeys } from "@/hooks/useNotes";
import { useAuthStore } from "@/stores/authStore";
import { deriveNoteTitleFromHtml, isEmptyDraftNote } from "@/utils/noteContent";
import type { Note } from "@shared/notes";

type EditorRoute = RouteProp<AppStackParamList, "Editor">;
type Navigation = StackNavigationProp<AppStackParamList, "Editor">;
const EDITOR_SURFACE_COLOR = "#1A1B1E";

export function NoteEditorScreen() {
  const navigation = useNavigation<Navigation>();
  const route = useRoute<EditorRoute>();
  const { noteId } = route.params;
  const queryClient = useQueryClient();

  const token = useAuthStore((state) => state.token);
  const notesQuery = useNotesQuery();
  const updateNoteMutation = useUpdateNoteMutation();
  const deleteNoteMutation = useDeleteNoteMutation();
  const foldersQuery = useFoldersQuery();

  const note = useMemo(
    () => (notesQuery.data ?? []).find((currentNote) => currentNote.id === noteId),
    [notesQuery.data, noteId],
  );

  const [content, setContent] = useState("");
  const debouncedContent = useDebounce(content, 100);
  const prevNoteId = useRef<string | null>(null);
  const hasInitializedContent = useRef(false);
  const hasUserEdited = useRef(false);
  const lastSavedContent = useRef("");
  const lastSavedTitle = useRef("");
  const isLeavingRef = useRef(false);
  const [menuAnchor, setMenuAnchor] = useState<{ x: number; y: number } | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isMoveOpen, setIsMoveOpen] = useState(false);
  const [isDeleteConfirmOpen, setIsDeleteConfirmOpen] = useState(false);
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    void notesQuery.refetch();
  }, [noteId]);

  useEffect(() => {
    // Only set content if we switched to a different note
    if (note && note.id !== prevNoteId.current) {
      const initialContent = note.content || "";
      setContent(initialContent);
      prevNoteId.current = note.id;
      hasInitializedContent.current = true;
      hasUserEdited.current = false;
      lastSavedContent.current = initialContent;
      lastSavedTitle.current = note.title || "Untitled";
      setIsEditing(false);
    }
  }, [note]);

  const handleEditorChange = useCallback((nextContent: string) => {
    hasUserEdited.current = true;
    setContent(nextContent);
  }, []);

  const saveNow = useCallback(async () => {
    if (!note) {
      return;
    }

    if (!hasInitializedContent.current || !hasUserEdited.current) {
      return;
    }

    const derivedTitle = deriveNoteTitleFromHtml(content);
    const isUnchanged =
      content === lastSavedContent.current && derivedTitle === lastSavedTitle.current;

    if (isUnchanged || updateNoteMutation.isPending) {
      return;
    }

    const payload: { content: string; title?: string } = { content };
    if (derivedTitle !== lastSavedTitle.current) {
      payload.title = derivedTitle;
    }

    const updatedNote = await updateNoteMutation.mutateAsync({
      noteId: note.id,
      payload,
    });
    lastSavedContent.current = updatedNote.content;
    lastSavedTitle.current = updatedNote.title;
  }, [content, note, updateNoteMutation]);

  useEffect(() => {
    const unsubscribe = navigation.addListener("beforeRemove", (event) => {
      if (isLeavingRef.current) {
        return;
      }

      event.preventDefault();
      isLeavingRef.current = true;

      const derivedTitle = deriveNoteTitleFromHtml(content);
      const isDraft = isEmptyDraftNote({ title: derivedTitle, content, isPinned: note?.isPinned });

      if (isDraft && note) {
        // If it's an empty draft, just delete it and leave
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
  }, [navigation, saveNow, content, note, deleteNoteMutation]);

  useEffect(() => {
    if (!note) {
      return;
    }
    if (!hasInitializedContent.current) {
      return;
    }
    if (!hasUserEdited.current) {
      return;
    }
    const derivedTitle = deriveNoteTitleFromHtml(debouncedContent);
    const isUnchanged =
      debouncedContent === lastSavedContent.current && derivedTitle === lastSavedTitle.current;
    if (isUnchanged) {
      return;
    }
    if (updateNoteMutation.isPending) {
      return;
    }

    const payload = {
      content: debouncedContent,
      ...(derivedTitle !== lastSavedTitle.current ? { title: derivedTitle } : {}),
    };

    updateNoteMutation.mutate({
      noteId: note.id,
      payload,
    }, {
      onSuccess: (updatedNote) => {
        lastSavedContent.current = updatedNote.content;
        lastSavedTitle.current = updatedNote.title;
      },
    });
  }, [debouncedContent, note, updateNoteMutation, updateNoteMutation.isPending]);

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

            const derivedTitle = deriveNoteTitleFromHtml(content);
            const isDraft = isEmptyDraftNote({ title: derivedTitle, content, isPinned: note?.isPinned });

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
          <View className="flex-row items-center gap-2">
            <Pressable
              onPress={() => {
                if (isEditing) {
                  void saveNow();
                }
                setIsEditing((previous) => !previous);
              }}
              className="rounded-md px-2 py-1"
              hitSlop={12}
            >
              <Text className="text-sm font-medium text-accent">{isEditing ? "Done" : "Edit"}</Text>
            </Pressable>
            <Pressable
              onPress={(event) => {
                setMenuAnchor({ x: event.nativeEvent.pageX, y: event.nativeEvent.pageY });
                setIsMenuOpen(true);
              }}
              className="rounded-md px-2 py-1"
              hitSlop={12}
            >
              <EllipsisVertical size={20} color="#eab308" />
            </Pressable>
          </View>
        </View>
      </View>

      <View className="flex-1">
        <Editor
          key={noteId}
          value={content}
          onChange={handleEditorChange}
          timestamp={note?.updatedAt || note?.createdAt}
          editable={isEditing}
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
        title="Delete Note"
        description="Are you sure you want to delete this note?"
        confirmLabel="Delete"
        destructive
        onConfirm={() => {
          void handleDeleteConfirm();
        }}
        onCancel={() => setIsDeleteConfirmOpen(false)}
      />
    </ScreenContainer>
  );
}
