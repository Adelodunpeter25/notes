import { FlatList, Text, View } from "react-native";
import { Folder as FolderIcon, Trash2, FileText } from "lucide-react-native";

import type { Folder } from "@shared/folders";
import { CardContainer, ListItem, Skeleton } from "@/components/common";
import type { GestureResponderEvent } from "react-native";

type FolderListProps = {
  folders: Folder[];
  trashCount?: number;
  allNotesCount?: number;
  isLoading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  onSelectFolder: (folder: Folder | 'all') => void;
  onSelectTrash?: () => void;
  onLongPressFolder?: (folder: Folder, event: GestureResponderEvent) => void;
};

export function FolderList({
  folders,
  trashCount = 0,
  allNotesCount = 0,
  isLoading = false,
  refreshing = false,
  onRefresh,
  onSelectFolder,
  onSelectTrash,
  onLongPressFolder,
}: FolderListProps) {
  if (isLoading) {
    return (
      <View className="px-4 pt-2">
        <Skeleton className="mb-2 h-14 w-full" />
        <Skeleton className="mb-2 h-14 w-full" />
        <Skeleton className="h-14 w-full" />
      </View>
    );
  }

  return (
    <CardContainer className="mt-3">
      <FlatList
        data={folders}
        keyExtractor={(item) => item.id}
        refreshing={refreshing}
        onRefresh={onRefresh}
        ListHeaderComponent={
          <ListItem
            title="All Notes"
            count={allNotesCount}
            icon={<FolderIcon size={18} color="#eab308" />}
            onPress={() => onSelectFolder('all')}
            showDivider={folders.length > 0 || !!onSelectTrash}
          />
        }
        renderItem={({ item, index }) => {
          const isLast = index === folders.length - 1 && !(onSelectTrash && trashCount > 0);
          return (
            <ListItem
              title={item.name}
              count={item.notesCount}
              icon={<FolderIcon size={18} color="#eab308" />}
              onPress={() => onSelectFolder(item)}
              onLongPress={(event) => onLongPressFolder?.(item, event)}
              showDivider={!isLast}
            />
          );
        }}
        ListFooterComponent={
          onSelectTrash ? (
            <ListItem
              title="Trash"
              count={trashCount}
              icon={<Trash2 size={18} color="#ff4444" />}
              onPress={onSelectTrash}
              showDivider={false}
            />
          ) : null
        }
      />
    </CardContainer>
  );
}
