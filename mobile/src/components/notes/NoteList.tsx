import { FlatList, Text, View, Alert, Pressable } from "react-native";
import { Pin, Trash2 } from "lucide-react-native";
import { Swipeable } from "react-native-gesture-handler";

import type { Note } from "@shared/notes";
import { ListItem, Skeleton } from "@/components/common";
import { deriveNotePreviewFromHtml, deriveNoteTitleFromHtml } from "@/utils/noteContent";
import { formatNoteDate } from "@/utils/formatDate";
import { useDeleteNoteMutation } from "@/hooks";

type NoteListProps = {
  notes: Note[];
  isLoading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  emptyText?: string;
  onSelectNote?: (note: Note) => void;
};

export function NoteList({
  notes,
  isLoading = false,
  refreshing = false,
  onRefresh,
  emptyText = "No notes yet.",
  onSelectNote,
}: NoteListProps) {
  const deleteNoteMutation = useDeleteNoteMutation();

  const handleDelete = (note: Note) => {
    Alert.alert(
      "Delete Note",
      "Are you sure you want to delete this note?",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: () => {
            void deleteNoteMutation.mutateAsync(note.id);
          }
        },
      ]
    );
  };

  if (isLoading) {
    return (
      <View className="px-4 pt-2">
        <Skeleton className="mb-2 h-16 w-full" />
        <Skeleton className="mb-2 h-16 w-full" />
        <Skeleton className="h-16 w-full" />
      </View>
    );
  }

  if (notes.length === 0) {
    return (
      <View className="items-center justify-center px-6 py-10">
        <Text className="text-sm text-textMuted">{emptyText}</Text>
      </View>
    );
  }

  const renderRightActions = (note: Note) => {
    return (
      <Pressable
        onPress={() => handleDelete(note)}
        className="bg-danger w-20 items-center justify-center"
      >
        <Trash2 size={24} color="#ffffff" />
      </Pressable>
    );
  };

  return (
    <FlatList
      data={notes}
      keyExtractor={(item) => item.id}
      refreshing={refreshing}
      onRefresh={onRefresh}
      renderItem={({ item }) => {
        const title = deriveNoteTitleFromHtml(item.content || "") || item.title?.trim() || "Untitled";
        const dateStr = formatNoteDate(item.updatedAt || item.createdAt);
        const preview = deriveNotePreviewFromHtml(item.content || "");

        return (
          <Swipeable
            renderRightActions={() => renderRightActions(item)}
            friction={2}
            rightThreshold={40}
          >
            <ListItem
              title={title}
              subtitle={`${dateStr} ${preview}`.trim()}
              icon={item.isPinned ? <Pin size={16} color="#eab308" /> : undefined}
              onPress={() => onSelectNote?.(item)}
              showChevron={false}
            />
          </Swipeable>
        );
      }}
    />
  );
}
