import { Text, View, Alert } from "react-native";
import { Pressable } from "react-native";
import { useState } from "react";
import { ChevronLeft, Plus, PenLine, Search } from "lucide-react-native";
import { useNavigation, useRoute, type RouteProp } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import type { AppStackParamList } from "@/navigation/types";
import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { NoteList, NoteContextMenu } from "@/components/notes";
import { ConfirmDialog, ContextMenu, type ContextMenuItem } from "@/components/common";
import {
  useCreateNoteMutation,
  useDeleteNoteMutation,
  useFolderNotesQuery,
  useNotesQuery,
  useFoldersQuery,
  useUpdateNoteMutation,
} from "@/hooks";
import type { Note } from "@shared/notes";

type FolderDetailsRoute = RouteProp<AppStackParamList, "FolderDetails">;
type Navigation = StackNavigationProp<AppStackParamList, "FolderDetails">;

export function FolderDetailsScreen() {
  const navigation = useNavigation<Navigation>();
  const route = useRoute<FolderDetailsRoute>();
  const { folderId, folderName } = route.params;

  const isAllNotes = folderId === 'all';
  
  const allNotesQuery = useNotesQuery();
  const folderNotesQuery = useFolderNotesQuery(isAllNotes ? "" : folderId);
  const notesQuery = isAllNotes ? allNotesQuery : folderNotesQuery;

  const foldersQuery = useFoldersQuery();
  const createNoteMutation = useCreateNoteMutation();
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

  const handleCreateNote = async () => {
    try {
      const created = await createNoteMutation.mutateAsync({
        folderId: isAllNotes ? undefined : folderId,
        title: "Untitled",
        content: "",
        isPinned: false,
      });
      navigation.navigate("Editor", { noteId: created.id, note: created });
    } catch (error) {
      console.error("Failed to create note in folder:", error);
    }
  };

  return (
    <ScreenContainer>
      <View className="flex-row items-center justify-between border-b border-border px-4 py-3 pb-2">
        <Pressable
          onPress={() => navigation.goBack()}
          className="flex-row items-center rounded-md py-1 pr-2"
          hitSlop={15}
        >
          <ChevronLeft size={22} color="#eab308" />
          <Text className="text-[17px] font-medium text-accent">Back</Text>
        </Pressable>
        
        <Text className="absolute left-0 right-0 text-center text-lg font-semibold text-text pointer-events-none">
          {folderName}
        </Text>

        <View className="flex-row items-center">
          <Pressable
            onPress={() => navigation.navigate("Search", { folderId: isAllNotes ? undefined : folderId })}
            className="rounded-md p-2 mr-1"
            hitSlop={10}
          >
            <Search size={20} color="#eab308" />
          </Pressable>
          <Pressable
            onPress={() => {
              void handleCreateNote();
            }}
            disabled={createNoteMutation.isPending}
            className="rounded-md p-2"
            hitSlop={10}
          >
            <Plus size={24} color="#eab308" />
          </Pressable>
        </View>
      </View>

      <View className="flex-1">
        <NoteList
          notes={notesQuery.data ?? []}
          folders={isAllNotes ? (foldersQuery.data ?? []) : []}
          isLoading={notesQuery.isLoading}
          refreshing={notesQuery.isRefetching}
          onRefresh={() => {
            void notesQuery.refetch();
          }}
          emptyText="No notes in this folder."
          onSelectNote={(note) => {
            navigation.navigate("Editor", { noteId: note.id, note });
          }}
          onLongPressNote={(note, event) => {
            setMenuAnchor({ x: event.nativeEvent.pageX, y: event.nativeEvent.pageY });
            setMenuNote(note);
          }}
        />
      </View>

      <Pressable
        onPress={() => {
          void handleCreateNote();
        }}
        disabled={createNoteMutation.isPending}
        className="absolute bottom-6 right-5 h-[63px] w-[63px] items-center justify-center rounded-full bg-accent shadow-lg active:scale-95"
      >
        <PenLine size={24} color="#000000" />
      </Pressable>

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
