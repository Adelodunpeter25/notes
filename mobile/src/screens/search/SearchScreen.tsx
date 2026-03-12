import { Pressable, Text, TextInput, View } from "react-native";
import { Search } from "lucide-react-native";
import { useNavigation } from "@react-navigation/native";

import { ScreenContainer } from "@/components/layout";
import { SearchResults } from "@/components/search";
import { useDebounce, useNotesQuery, useSearch, useFoldersQuery } from "@/hooks";
import { useEffect, useRef } from "react";

export function SearchScreen() {
  const navigation = useNavigation();
  const { searchQuery, handleSearchChange, closeSearch } = useSearch();
  const debouncedQuery = useDebounce(searchQuery, 250);
  const inputRef = useRef<TextInput>(null);

  const resultsQuery = useNotesQuery({
    q: debouncedQuery.trim() || undefined,
  });
  const foldersQuery = useFoldersQuery();

  useEffect(() => {
    const timer = setTimeout(() => {
      inputRef.current?.focus();
    }, 60);
    return () => clearTimeout(timer);
  }, []);

  return (
    <ScreenContainer>
      <View className="border-b border-border px-4 py-3">
        <View className="flex-row items-center">
          <View className="mr-3 flex-1 flex-row items-center rounded-xl border border-border bg-surfaceSecondary px-3">
            <Search size={16} color="#a0a0a0" />
            <TextInput
              ref={inputRef}
              value={searchQuery}
              onChangeText={handleSearchChange}
              placeholder="Search notes"
              placeholderTextColor="#6f6f6f"
              autoFocus
              className="ml-2 flex-1 py-2.5 text-[15px] text-text"
            />
          </View>

          <Pressable
            onPress={() => {
              closeSearch();
              navigation.goBack();
            }}
            className="px-1 py-1"
          >
            <Text className="text-sm font-medium text-accent">Cancel</Text>
          </Pressable>
        </View>
      </View>

      <View className="flex-1">
        <SearchResults
          query={searchQuery}
          notes={resultsQuery.data ?? []}
          folders={foldersQuery.data ?? []}
          isLoading={resultsQuery.isLoading}
          refreshing={resultsQuery.isRefetching}
          onRefresh={() => {
            void resultsQuery.refetch();
          }}
          onSelectNote={(note) => {
            // @ts-ignore
            navigation.navigate("Editor", { noteId: note.id });
          }}
        />
      </View>
    </ScreenContainer>
  );
}
