import { Text, View } from "react-native";
import { Pressable } from "react-native";
import { useState } from "react";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { Search } from "lucide-react-native";

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
      <View className="flex-row items-center justify-between border-b border-border px-4 py-3">
        <Text className="text-xl font-semibold text-text">Notes</Text>
        <Pressable onPress={() => navigation.navigate("Search")} className="rounded-md p-1.5">
          <Search size={18} color="#eab308" />
        </Pressable>
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
              refreshing={foldersQuery.isRefetching}
              onRefresh={() => {
                void foldersQuery.refetch();
              }}
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
              refreshing={notesQuery.isRefetching}
              onRefresh={() => {
                void notesQuery.refetch();
              }}
              emptyText="No notes yet."
              onSelectNote={(note) => {
                navigation.navigate("Editor", { noteId: note.id });
            }}
          />
        </View>
      )}
      </View>
      <BottomBar activeTab={activeTab} onChangeTab={setActiveTab} />
    </ScreenContainer>
  );
}
