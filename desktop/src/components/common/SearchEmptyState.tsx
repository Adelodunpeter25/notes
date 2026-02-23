import { Search } from "lucide-react";

import { EmptyState } from "./EmptyState";

type SearchEmptyStateProps = {
  query?: string;
};

export function SearchEmptyState({ query }: SearchEmptyStateProps) {
  const hasQuery = Boolean(query?.trim());

  return (
    <EmptyState
      icon={<Search size={16} />}
      prompt="Search"
      title={hasQuery ? "No results found" : "Start searching"}
      description={
        hasQuery
          ? `No notes match “${query?.trim()}”. Try a different keyword.`
          : "Type a keyword to search across your notes and folders."
      }
    />
  );
}
