import { Text, View } from "react-native";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { Button } from "@/components/common";
import { FolderList, NoteList } from "@/components/notes";
import { useFoldersQuery, useNotesQuery } from "@/hooks";
import type { AppStackParamList } from "@/navigation/types";
import { useAuthStore } from "@/stores/authStore";

type Navigation = StackNavigationProp<AppStackParamList, "Dashboard">;

export function DashboardScreen() {
  const navigation = useNavigation<Navigation>();
  const clearAuth = useAuthStore((state) => state.clearAuth);
  const foldersQuery = useFoldersQuery();
  const notesQuery = useNotesQuery();

  return (
    <ScreenContainer>
      <View className="border-b border-border px-4 py-3">
        <Text className="text-xl font-semibold text-text">Notes</Text>
      </View>

      <View className="flex-1">
        <View className="border-b border-border">
          <View className="flex-row items-center justify-between px-4 py-3">
            <Text className="text-base font-semibold text-text">Folders</Text>
            <Button onPress={clearAuth} title="Logout" variant="ghost" size="sm" />
          </View>
          <FolderList
            folders={foldersQuery.data ?? []}
            isLoading={foldersQuery.isLoading}
            onSelectFolder={(folder) => {
              navigation.navigate("FolderDetails", {
                folderId: folder.id,
                folderName: folder.name,
              });
            }}
          />
        </View>

        <View className="flex-1">
          <View className="px-4 py-3">
            <Text className="text-base font-semibold text-text">All Notes</Text>
          </View>
          <NoteList
            notes={notesQuery.data ?? []}
            isLoading={notesQuery.isLoading}
            emptyText="No notes yet."
          />
        </View>
      </View>
    </ScreenContainer>
  );
}
