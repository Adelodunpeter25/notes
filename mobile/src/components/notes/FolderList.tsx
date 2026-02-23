import { FlatList, Text, View } from "react-native";
import { Folder as FolderIcon } from "lucide-react-native";

import type { Folder } from "@shared/folders";
import { ListItem, Skeleton } from "@/components/common";

type FolderListProps = {
  folders: Folder[];
  isLoading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  onSelectFolder: (folder: Folder) => void;
};

export function FolderList({
  folders,
  isLoading = false,
  refreshing = false,
  onRefresh,
  onSelectFolder,
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

  if (folders.length === 0) {
    return (
      <View className="items-center justify-center px-6 py-10">
        <Text className="text-sm text-textMuted">No folders yet.</Text>
      </View>
    );
  }

  return (
    <FlatList
      data={folders}
      keyExtractor={(item) => item.id}
      refreshing={refreshing}
      onRefresh={onRefresh}
      renderItem={({ item }) => (
        <ListItem
          title={item.name}
          count={item.notesCount}
          icon={<FolderIcon size={18} color="#eab308" />}
          onPress={() => onSelectFolder(item)}
        />
      )}
    />
  );
}
