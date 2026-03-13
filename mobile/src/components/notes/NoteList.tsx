import { FlatList, Text, View, Pressable } from "react-native";
import { Pin, Trash2, Folder as FolderIcon } from "lucide-react-native";
import { Swipeable } from "react-native-gesture-handler";
import { useState, useRef } from "react";

import type { Note } from "@shared/notes";
import type { Folder } from "@shared/folders";
import { ListItem, Skeleton, ConfirmDialog } from "@/components/common";
import { deriveNotePreviewFromHtml, deriveNoteTitleFromHtml } from "@/utils/noteContent";
import { formatNoteDate } from "@/utils/formatDate";
import { useDeleteNoteMutation } from "@/hooks";
import type { GestureResponderEvent } from "react-native";

type NoteListProps = {
  notes: Note[];
  folders?: Folder[];
  isLoading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  emptyText?: string;
  onSelectNote?: (note: Note) => void;
  onLongPressNote?: (note: Note, event: GestureResponderEvent) => void;
  searchQuery?: string;
};

export function NoteList({
  notes,
  folders = [],
  isLoading = false,
  refreshing = false,
  onRefresh,
  emptyText = "No notes yet.",
  onSelectNote,
  onLongPressNote,
  searchQuery,
}: NoteListProps) {
  const deleteNoteMutation = useDeleteNoteMutation();
  const [noteToDelete, setNoteToDelete] = useState<Note | null>(null);
  const swipeableRefs = useRef<{ [key: string]: Swipeable | null }>({});

  const handleDelete = async () => {
    if (noteToDelete) {
      await deleteNoteMutation.mutateAsync(noteToDelete.id);
      setNoteToDelete(null);
    }
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

  const renderLeftActions = () => {
    return (
      <View className="bg-danger w-28 h-full items-center justify-center">
        <Trash2 size={24} color="#ffffff" />
      </View>
    );
  };

  return (
    <>
      <FlatList
        data={notes}
        keyExtractor={(item) => item.id}
        refreshing={refreshing}
        onRefresh={onRefresh}
        renderItem={({ item }) => {
          const title = deriveNoteTitleFromHtml(item.content || "") || item.title?.trim() || "Untitled";
          const dateStr = formatNoteDate(item.updatedAt || item.createdAt);
          const preview = deriveNotePreviewFromHtml(item.content || "");
          const folderName = folders.find((f) => f.id === item.folderId)?.name;

          return (
            <Swipeable
              ref={(ref) => { swipeableRefs.current[item.id] = ref; }}
              renderLeftActions={renderLeftActions}
              onSwipeableOpen={() => {
                setNoteToDelete(item);
                // Keep the swipeable open while the confirmation dialog is visible.
                // It will be closed onCancel.
              }}
              friction={1}
              leftThreshold={22}
              overshootLeft={false}
            >
              <ListItem
                title={title}
                subtitle={
                  <View className="flex-row items-center">
                    <Text className="text-[13px] text-textMuted">{dateStr}</Text>
                    {folderName && (
                      <>
                        <Text className="text-[13px] text-textMuted"> · </Text>
                        <FolderIcon size={12} color="#eab308" />
                        <Text className="ml-1 text-[13px] text-accent">{folderName}</Text>
                      </>
                    )}
                    {preview && (
                      <Text className="text-[13px] text-textMuted"> · {preview}</Text>
                    )}
                  </View>
                }
                titleClassName="text-[16px]"
                subtitleClassName="text-[13px]"
                icon={item.isPinned ? <Pin size={16} color="#eab308" /> : undefined}
                onPress={() => onSelectNote?.(item)}
                onLongPress={(event) => onLongPressNote?.(item, event)}
                showChevron={false}
                searchQuery={searchQuery}
              />
            </Swipeable>
          );
        }}
      />

      <ConfirmDialog
        visible={!!noteToDelete}
        title="Delete Note"
        description="Are you sure you want to delete this note? This action cannot be undone."
        confirmLabel="Delete"
        destructive
        onConfirm={handleDelete}
        onCancel={() => {
          if (noteToDelete) {
            swipeableRefs.current[noteToDelete.id]?.close();
          }
          setNoteToDelete(null);
        }}
      />
    </>
  );
}
