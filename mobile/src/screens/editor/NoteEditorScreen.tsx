import { useEffect, useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { ChevronLeft } from "lucide-react-native";
import { useNavigation, useRoute, type RouteProp } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import type { AppStackParamList } from "@/navigation/types";
import { ScreenContainer } from "@/components/layout";
import { Editor } from "@/components/editor";
import { useDebounce, useNotesQuery, useUpdateNoteMutation } from "@/hooks";

type EditorRoute = RouteProp<AppStackParamList, "Editor">;
type Navigation = StackNavigationProp<AppStackParamList, "Editor">;

export function NoteEditorScreen() {
  const navigation = useNavigation<Navigation>();
  const route = useRoute<EditorRoute>();
  const { noteId } = route.params;

  const notesQuery = useNotesQuery();
  const updateNoteMutation = useUpdateNoteMutation();

  const note = useMemo(
    () => (notesQuery.data ?? []).find((currentNote) => currentNote.id === noteId),
    [notesQuery.data, noteId],
  );

  const [content, setContent] = useState("");
  const debouncedContent = useDebounce(content, 350);

  useEffect(() => {
    setContent(note?.content ?? "");
  }, [note?.id, note?.content]);

  useEffect(() => {
    if (!note) {
      return;
    }
    if (debouncedContent === note.content) {
      return;
    }

    updateNoteMutation.mutate({
      noteId: note.id,
      payload: {
        content: debouncedContent,
      },
    });
  }, [debouncedContent, note, updateNoteMutation]);

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
        <Text className="text-lg font-semibold text-text">{note?.title || "Untitled"}</Text>
      </View>

      <View className="flex-1 px-4 py-4">
        <Editor value={content} onChange={setContent} />
      </View>
    </ScreenContainer>
  );
}
