import { Text, View } from "react-native";
import { Pressable } from "react-native";
import { ChevronLeft } from "lucide-react-native";
import { useNavigation, useRoute, type RouteProp } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import type { AppStackParamList } from "@/navigation/types";
import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { NoteList } from "@/components/notes";
import { useFolderNotesQuery } from "@/hooks";

type FolderDetailsRoute = RouteProp<AppStackParamList, "FolderDetails">;
type Navigation = StackNavigationProp<AppStackParamList, "FolderDetails">;

export function FolderDetailsScreen() {
  const navigation = useNavigation<Navigation>();
  const route = useRoute<FolderDetailsRoute>();
  const { folderId, folderName } = route.params;

  const notesQuery = useFolderNotesQuery(folderId);

  return (
    <ScreenContainer>
      <View className="border-b border-border px-4 py-3">
        <Pressable
          onPress={() => navigation.goBack()}
          className="mb-2 flex-row items-center self-start rounded-md px-1 py-1"
        >
          <ChevronLeft size={18} color="#eab308" />
          <Text className="ml-1 text-sm font-medium text-accent">Back</Text>
        </Pressable>
        <Text className="text-lg font-semibold text-text">{folderName}</Text>
        <Text className="mt-1 text-xs text-textMuted">Notes in this folder</Text>
      </View>

      <View className="flex-1">
        <NoteList
          notes={notesQuery.data ?? []}
          isLoading={notesQuery.isLoading}
          emptyText="No notes in this folder."
          onSelectNote={(note) => {
            navigation.navigate("Editor", { noteId: note.id });
          }}
        />
      </View>
    </ScreenContainer>
  );
}
