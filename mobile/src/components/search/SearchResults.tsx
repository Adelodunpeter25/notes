import { Text, View } from "react-native";

import type { Note } from "@shared/notes";
import type { Folder } from "@shared/folders";
import { NoteList } from "@/components/notes";

type SearchResultsProps = {
  query: string;
  notes: Note[];
  folders?: Folder[];
  isLoading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  onSelectNote?: (note: Note) => void;
};

export function SearchResults({
  query,
  notes,
  folders = [],
  isLoading = false,
  refreshing = false,
  onRefresh,
  onSelectNote,
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
      folders={folders}
      isLoading={isLoading}
      refreshing={refreshing}
      onRefresh={onRefresh}
      onSelectNote={onSelectNote}
      emptyText={`No results for "${query}"`}
      searchQuery={query}
    />
  );
}
