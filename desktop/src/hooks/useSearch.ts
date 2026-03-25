import { useCallback, useMemo, useRef, useEffect } from "react";
import { useUiStore } from "@/stores";

export function useSearch() {
    const isSearchExpanded = useUiStore((state) => state.isSearchExpanded);
    const setIsSearchExpanded = useUiStore((state) => state.setIsSearchExpanded);
    const searchQuery = useUiStore((state) => state.searchQuery);
    const setSearchQuery = useUiStore((state) => state.setSearchQuery);
    const inputRef = useRef<HTMLInputElement>(null);

    const toggleSearch = useCallback(() => {
        if (isSearchExpanded) {
            setSearchQuery("");
            setIsSearchExpanded(false);
        } else {
            setIsSearchExpanded(true);
        }
    }, [isSearchExpanded, setIsSearchExpanded, setSearchQuery]);

    const closeSearch = useCallback(() => {
        setIsSearchExpanded(false);
        setSearchQuery("");
    }, [setIsSearchExpanded, setSearchQuery]);

    const openSearch = useCallback(() => {
        setIsSearchExpanded(true);
    }, [setIsSearchExpanded]);

    const handleSearchChange = useCallback(
        (value: string) => {
            setSearchQuery(value);
        },
        [setSearchQuery]
    );

    // Focus input when expanded
    useEffect(() => {
        if (isSearchExpanded && inputRef.current) {
            inputRef.current.focus();
        }
    }, [isSearchExpanded]);

    return useMemo(
        () => ({
            isSearchExpanded,
            searchQuery,
            toggleSearch,
            closeSearch,
            openSearch,
            handleSearchChange,
            inputRef,
        }),
        [isSearchExpanded, searchQuery, toggleSearch, closeSearch, openSearch, handleSearchChange]
    );
}
