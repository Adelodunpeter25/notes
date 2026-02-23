import { Text, View } from "react-native";

import type { Note } from "@shared/notes";
import { NoteList } from "@/components/notes";

type SearchResultsProps = {
  query: string;
  notes: Note[];
  isLoading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
};

export function SearchResults({
  query,
  notes,
  isLoading = false,
  refreshing = false,
  onRefresh,
}: SearchResultsProps) {
  if (!query.trim()) {
    return (
      <View className="items-center justify-center px-6 py-10">
        <Text className="text-sm text-textMuted">Type to search notes.</Text>
      </View>
    );
  }

  return (
    <NoteList
      notes={notes}
      isLoading={isLoading}
      refreshing={refreshing}
      onRefresh={onRefresh}
      emptyText={`No results for "${query}"`}
    />
  );
}
