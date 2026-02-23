import { Text, View } from "react-native";
import { useState } from "react";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { FolderList, NoteList } from "@/components/notes";
import { BottomBar } from "@/components/layout";
import { useFoldersQuery, useNotesQuery } from "@/hooks";
import type { AppStackParamList } from "@/navigation/types";

type Navigation = StackNavigationProp<AppStackParamList, "Dashboard">;

export function DashboardScreen() {
  const navigation = useNavigation<Navigation>();
  const [activeTab, setActiveTab] = useState<"notes" | "folders">("notes");
  const foldersQuery = useFoldersQuery();
  const notesQuery = useNotesQuery();

  return (
    <ScreenContainer>
      <View className="border-b border-border px-4 py-3">
        <Text className="text-xl font-semibold text-text">Notes</Text>
      </View>

      <View className="flex-1">
        {activeTab === "folders" ? (
          <View className="flex-1">
            <View className="px-4 py-3">
              <Text className="text-base font-semibold text-text">Folders</Text>
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
        ) : (
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
        )}
      </View>
      <BottomBar activeTab={activeTab} onChangeTab={setActiveTab} />
    </ScreenContainer>
  );
}
