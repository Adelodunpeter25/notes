import { FlatList, Text, View } from "react-native";
import { Pin } from "lucide-react-native";

import type { Note } from "@shared/notes";
import { ListItem, Skeleton } from "@/components/common";
import { deriveNotePreviewFromHtml, deriveNoteTitleFromHtml } from "@/utils/noteContent";
import { formatNoteDate } from "@/utils/formatDate";

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
          <ListItem
            title={title}
            subtitle={`${dateStr} ${preview}`.trim()}
            icon={item.isPinned ? <Pin size={16} color="#eab308" /> : undefined}
            onPress={() => onSelectNote?.(item)}
            showChevron={false}
          />
        );
      }}
    />
  );
}
