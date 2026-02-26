import { Text, View, Alert } from "react-native";
import { Pressable } from "react-native";
import { useState } from "react";
import { ChevronLeft } from "lucide-react-native";
import { useNavigation, useRoute, type RouteProp } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import type { AppStackParamList } from "@/navigation/types";
import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { NoteList, NoteContextMenu } from "@/components/notes";
import { ConfirmDialog, ContextMenu, type ContextMenuItem } from "@/components/common";
import { useDeleteNoteMutation, useFolderNotesQuery, useFoldersQuery, useUpdateNoteMutation } from "@/hooks";
import type { Note } from "@shared/notes";

type FolderDetailsRoute = RouteProp<AppStackParamList, "FolderDetails">;
type Navigation = StackNavigationProp<AppStackParamList, "FolderDetails">;

export function FolderDetailsScreen() {
  const navigation = useNavigation<Navigation>();
  const route = useRoute<FolderDetailsRoute>();
  const { folderId, folderName } = route.params;

  const notesQuery = useFolderNotesQuery(folderId);
  const foldersQuery = useFoldersQuery();
  const updateNoteMutation = useUpdateNoteMutation();
  const deleteNoteMutation = useDeleteNoteMutation();
  const [menuNote, setMenuNote] = useState<Note | null>(null);
  const [menuAnchor, setMenuAnchor] = useState<{ x: number; y: number } | null>(null);
  const [noteToDelete, setNoteToDelete] = useState<Note | null>(null);
  const [noteToMove, setNoteToMove] = useState<Note | null>(null);

  const handlePinNote = async (note: Note) => {
    await updateNoteMutation.mutateAsync({
      noteId: note.id,
      payload: { isPinned: !note.isPinned },
    });
  };

  const handleDeleteNote = async (note: Note) => {
    setNoteToDelete(note);
  };

  const handleConfirmDeleteNote = async () => {
    if (!noteToDelete) return;
    await deleteNoteMutation.mutateAsync(noteToDelete.id);
    setNoteToDelete(null);
  };

  const handleMoveNote = (note: Note) => {
    const moveTargets = (foldersQuery.data ?? []).filter((folder) => folder.id !== note.folderId);
    if (moveTargets.length === 0) {
      Alert.alert("No folders", "Create a folder first.");
      return;
    }
    setNoteToMove(note);
  };

  const moveTargets = (foldersQuery.data ?? []).filter((folder) => folder.id !== noteToMove?.folderId);
  const moveItems: (ContextMenuItem | "separator")[] = moveTargets.map((folder) => ({
    label: folder.name,
    onPress: () => {
      if (!noteToMove) return;
      void updateNoteMutation.mutateAsync({
        noteId: noteToMove.id,
        payload: { folderId: folder.id },
      });
      setNoteToMove(null);
      setMenuAnchor(null);
    },
  }));

  return (
    <ScreenContainer>
      <View className="border-b border-border px-4 py-3">
        <Pressable
          onPress={() => navigation.goBack()}
          className="mb-2 flex-row items-center self-start rounded-md px-1 py-1"
        >
          <ChevronLeft size={18} color="#eab308" />
          <Text className="ml-1 text-sm font-medium text-accent">Back</Text>
        </Pressable>
        <Text className="text-lg font-semibold text-text">{folderName}</Text>
        <Text className="mt-1 text-xs text-textMuted">Notes in this folder</Text>
      </View>

      <View className="flex-1">
        <NoteList
          notes={notesQuery.data ?? []}
          isLoading={notesQuery.isLoading}
          refreshing={notesQuery.isRefetching}
          onRefresh={() => {
            void notesQuery.refetch();
          }}
          emptyText="No notes in this folder."
          onSelectNote={(note) => {
            navigation.navigate("Editor", { noteId: note.id });
          }}
          onLongPressNote={(note, event) => {
            setMenuAnchor({ x: event.nativeEvent.pageX, y: event.nativeEvent.pageY });
            setMenuNote(note);
          }}
        />
      </View>

      <NoteContextMenu
        visible={!!menuNote}
        note={menuNote}
        anchor={menuAnchor}
        onClose={() => {
          setMenuNote(null);
        }}
        onPin={handlePinNote}
        onMove={handleMoveNote}
        onDelete={handleDeleteNote}
      />

      <ContextMenu
        visible={!!noteToMove}
        anchor={menuAnchor}
        title="Move to Folder"
        items={moveItems}
        onClose={() => {
          setNoteToMove(null);
          setMenuAnchor(null);
        }}
      />

      <ConfirmDialog
        visible={!!noteToDelete}
        title="Delete Note"
        description="Are you sure you want to delete this note?"
        confirmLabel="Delete"
        destructive
        onConfirm={handleConfirmDeleteNote}
        onCancel={() => setNoteToDelete(null)}
      />
    </ScreenContainer>
  );
}
