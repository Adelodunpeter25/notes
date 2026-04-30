import { useQuery } from "@tanstack/react-query";
import { invoke } from "@tauri-apps/api/core";

export type NoteCounts = {
  allNotes: number;
  trash: number;
};

export function useNoteCountsQuery() {
  return useQuery({
    queryKey: ["note-counts"],
    queryFn: () => invoke<NoteCounts>("get_note_counts"),
  });
}

