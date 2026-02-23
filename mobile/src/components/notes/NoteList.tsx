import { FlatList, Text, View } from "react-native";
import { Pin } from "lucide-react-native";

import type { Note } from "@shared/notes";
import { ListItem, Skeleton } from "@/components/common";
import { EditorPreview } from "@/components/editor";

type NoteListProps = {
  notes: Note[];
  isLoading?: boolean;
  emptyText?: string;
  onSelectNote?: (note: Note) => void;
};

export function NoteList({
  notes,
  isLoading = false,
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
      renderItem={({ item }) => {
        const title = item.title?.trim() || "Untitled";

        return (
          <ListItem
            title={title}
            subtitle={<EditorPreview content={item.content || ""} />}
            icon={item.isPinned ? <Pin size={16} color="#eab308" /> : undefined}
            onPress={() => onSelectNote?.(item)}
            showChevron={false}
          />
        );
      }}
    />
  );
}
