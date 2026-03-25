import { useCallback, useMemo, useState } from "react";

export function useSearch(initialQuery = "") {
  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [isSearchExpanded, setIsSearchExpanded] = useState(false);

  const toggleSearch = useCallback(() => {
    setIsSearchExpanded((previous) => {
      const next = !previous;
      if (!next) {
        setSearchQuery("");
      }
      return next;
    });
  }, []);

  const closeSearch = useCallback(() => {
    setIsSearchExpanded(false);
    setSearchQuery("");
  }, []);

  const openSearch = useCallback(() => {
    setIsSearchExpanded(true);
  }, []);

  const handleSearchChange = useCallback((value: string) => {
    setSearchQuery(value);
  }, []);

  return useMemo(
    () => ({
      isSearchExpanded,
      searchQuery,
      setSearchQuery,
      setIsSearchExpanded,
      toggleSearch,
      closeSearch,
      openSearch,
      handleSearchChange,
    }),
    [isSearchExpanded, searchQuery, toggleSearch, closeSearch, openSearch, handleSearchChange],
  );
}
