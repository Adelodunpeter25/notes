import { Text, View } from "react-native";
import { useRoute, type RouteProp } from "@react-navigation/native";

import type { AppStackParamList } from "@/navigation/types";
import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { NoteList } from "@/components/notes";
import { useFolderNotesQuery } from "@/hooks";

type FolderDetailsRoute = RouteProp<AppStackParamList, "FolderDetails">;

export function FolderDetailsScreen() {
  const route = useRoute<FolderDetailsRoute>();
  const { folderId, folderName } = route.params;

  const notesQuery = useFolderNotesQuery(folderId);

  return (
    <ScreenContainer>
      <View className="border-b border-border px-4 py-3">
        <Text className="text-lg font-semibold text-text">{folderName}</Text>
        <Text className="mt-1 text-xs text-textMuted">Notes in this folder</Text>
      </View>

      <View className="flex-1">
        <NoteList
          notes={notesQuery.data ?? []}
          isLoading={notesQuery.isLoading}
          emptyText="No notes in this folder."
        />
      </View>
    </ScreenContainer>
  );
}
