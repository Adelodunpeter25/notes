import { FlatList, Pressable, Text, View } from "react-native";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { ChevronLeft } from "lucide-react-native";
import { useState } from "react";

import { ScreenContainer } from "@/components/layout";
import { BottomBar } from "@/components/layout";
import { ConfirmDialog, Skeleton } from "@/components/common";
import { useTrashQuery, useClearTrashMutation } from "@/hooks";
import { deriveNoteTitleFromHtml } from "@shared-utils/noteContent";
import { formatNoteDate } from "@shared-utils/formatDate";
import type { AppStackParamList } from "@/navigation/types";

type Navigation = StackNavigationProp<AppStackParamList, "Trash">;

export function TrashScreen() {
  const navigation = useNavigation<Navigation>();
  const { data: notes = [], isLoading } = useTrashQuery();
  const clearTrashMutation = useClearTrashMutation();
  const [confirmClear, setConfirmClear] = useState(false);

  return (
    <ScreenContainer>
      <View className="flex-row items-center justify-between border-b border-border px-4 py-4">
        <View className="flex-row items-center gap-2">
          <Pressable onPress={() => navigation.goBack()} hitSlop={10}>
            <ChevronLeft size={20} color="#eab308" />
          </Pressable>
          <Text className="text-xl font-semibold text-text">Trash</Text>
        </View>
        {notes.length > 0 && (
          <Pressable onPress={() => setConfirmClear(true)} hitSlop={10}>
            <Text className="text-sm font-medium text-red-400">Empty</Text>
          </Pressable>
        )}
      </View>

      {isLoading ? (
        <View className="px-4 pt-2">
          <Skeleton className="mb-2 h-16 w-full" />
          <Skeleton className="mb-2 h-16 w-full" />
          <Skeleton className="h-16 w-full" />
        </View>
      ) : notes.length === 0 ? (
        <View className="flex-1 items-center justify-center">
          <Text className="text-sm text-textMuted">Trash is empty</Text>
        </View>
      ) : (
        <FlatList
          data={notes}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => {
            const title = deriveNoteTitleFromHtml(item.content || "") || item.title || "Untitled";
            const date = formatNoteDate(item.deletedAt || item.updatedAt);
            return (
              <Pressable
                onPress={() => navigation.navigate("Editor", { noteId: item.id, note: item, isTrash: true })}
                className="border-b border-border px-4 py-3 active:bg-white/5"
              >
                <Text className="text-[15px] font-medium text-text" numberOfLines={1}>{title}</Text>
                <Text className="mt-0.5 text-[12px] text-textMuted">{date}</Text>
              </Pressable>
            );
          }}
        />
      )}

      <ConfirmDialog
        visible={confirmClear}
        title="Empty Trash?"
        description="All notes will be permanently deleted. This cannot be undone."
        confirmLabel="Empty Trash"
        destructive
        onConfirm={() => { clearTrashMutation.mutate(); setConfirmClear(false); }}
        onCancel={() => setConfirmClear(false)}
      />

      <BottomBar
        activeTab="trash"
        onChangeTab={(tab) => {
          if (tab === "trash") return;
          if (tab === "settings") {
            navigation.navigate("Settings");
            return;
          }
          navigation.navigate("Dashboard");
        }}
      />
    </ScreenContainer>
  );
}
