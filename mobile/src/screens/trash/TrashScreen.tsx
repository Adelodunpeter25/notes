import { FlatList, Pressable, Text, View, Alert } from "react-native";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { ChevronLeft, RotateCcw, Trash2 } from "lucide-react-native";
import { useState } from "react";

import { ScreenContainer } from "@/components/layout";
import { ConfirmDialog, Skeleton } from "@/components/common";
import { useTrashQuery, useClearTrashMutation, useRestoreNoteMutation, usePermanentlyDeleteNoteMutation } from "@/hooks";
import { deriveNoteTitleFromHtml } from "@shared-utils/noteContent";
import { formatNoteDate } from "@shared-utils/formatDate";
import type { AppStackParamList } from "@/navigation/types";
import type { Note } from "@shared/notes";

type Navigation = StackNavigationProp<AppStackParamList, "Trash">;

export function TrashScreen() {
  const navigation = useNavigation<Navigation>();
  const { data: notes = [], isLoading, isRefetching, refetch } = useTrashQuery();
  const clearTrashMutation = useClearTrashMutation();
  const restoreNoteMutation = useRestoreNoteMutation();
  const deletePermanentlyMutation = usePermanentlyDeleteNoteMutation();
  const [confirmClear, setConfirmClear] = useState(false);
  const [noteToDelete, setNoteToDelete] = useState<Note | null>(null);

  const handleRestoreNote = async (note: Note) => {
    try {
      await restoreNoteMutation.mutateAsync(note.id);
    } catch (error) {
      Alert.alert("Error", "Failed to restore note");
    }
  };

  const handleDeletePermanently = async () => {
    if (!noteToDelete) return;
    try {
      await deletePermanentlyMutation.mutateAsync(noteToDelete.id);
      setNoteToDelete(null);
    } catch (error) {
      Alert.alert("Error", "Failed to delete note");
    }
  };

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
        <View className="flex-row items-center justify-between">
          <Text className="text-lg font-semibold text-text">Trash</Text>
          {notes.length > 0 && (
            <Pressable onPress={() => setConfirmClear(true)} hitSlop={10} className="rounded-md px-2 py-1">
              <Text className="text-sm font-medium text-red-400">Empty All</Text>
            </Pressable>
          )}
        </View>
      </View>

      {isLoading ? (
        <View className="px-4 pt-2">
          <Skeleton className="mb-2 h-16 w-full" />
          <Skeleton className="mb-2 h-16 w-full" />
          <Skeleton className="h-16 w-full" />
        </View>
      ) : notes.length === 0 ? (
        <View className="flex-1 items-center justify-center">
          <Text className="text-sm text-textMuted">Trash is empty</Text>
        </View>
      ) : (
        <FlatList
          data={notes}
          keyExtractor={(item) => item.id}
          refreshing={isRefetching}
          onRefresh={() => {
            void refetch();
          }}
          renderItem={({ item }) => {
            const title = deriveNoteTitleFromHtml(item.content || "") || item.title || "Untitled";
            const date = formatNoteDate(item.deletedAt || item.updatedAt);
            return (
              <View className="border-b border-border px-4 py-3">
                <Pressable
                  onPress={() => navigation.navigate("Editor", { noteId: item.id, note: item, isTrash: true })}
                  className="mb-2"
                >
                  <Text className="text-[15px] font-medium text-text" numberOfLines={1}>{title}</Text>
                  <Text className="mt-0.5 text-[12px] text-textMuted">{date}</Text>
                </Pressable>
                <View className="flex-row gap-2">
                  <Pressable
                    onPress={() => handleRestoreNote(item)}
                    disabled={restoreNoteMutation.isPending}
                    className="flex-1 flex-row items-center justify-center rounded-lg border border-accent/30 bg-accent/10 py-2"
                  >
                    <RotateCcw size={16} color="#eab308" />
                    <Text className="ml-2 text-sm font-medium text-accent">Restore</Text>
                  </Pressable>
                  <Pressable
                    onPress={() => setNoteToDelete(item)}
                    className="flex-1 flex-row items-center justify-center rounded-lg border border-danger/30 bg-danger/10 py-2"
                  >
                    <Trash2 size={16} color="#ff4444" />
                    <Text className="ml-2 text-sm font-medium text-danger">Delete</Text>
                  </Pressable>
                </View>
              </View>
            );
          }}
        />
      )}

      <ConfirmDialog
        visible={confirmClear}
        title="Empty Trash?"
        description="All notes will be permanently deleted. This cannot be undone."
        confirmLabel="Empty Trash"
        destructive
        onConfirm={() => { clearTrashMutation.mutate(); setConfirmClear(false); }}
        onCancel={() => setConfirmClear(false)}
      />

      <ConfirmDialog
        visible={!!noteToDelete}
        title="Delete Forever?"
        description="This note will be permanently deleted. This cannot be undone."
        confirmLabel="Delete Forever"
        destructive
        onConfirm={handleDeletePermanently}
        onCancel={() => setNoteToDelete(null)}
      />
    </ScreenContainer>
  );
}
