import React from "react";
import { Pin, FolderInput, Trash2 } from "lucide-react-native";
import { ContextMenu, ContextMenuItem } from "@/components/common";
import { Note } from "@shared/notes";

interface NoteContextMenuProps {
    visible: boolean;
    note: Note | null;
    anchor?: { x: number; y: number } | null;
    onClose: () => void;
    onPin: (note: Note) => void;
    onMove: (note: Note) => void;
    onDelete: (note: Note) => void;
}

export function NoteContextMenu({
    visible,
    note,
    anchor,
    onClose,
    onPin,
    onMove,
    onDelete,
}: NoteContextMenuProps) {
    if (!note) return null;

    const items: (ContextMenuItem | "separator")[] = [
        {
            label: note.isPinned ? "Unpin" : "Pin",
            icon: Pin,
            onPress: () => onPin(note),
        },
        {
            label: "Move to Folder",
            icon: FolderInput,
            onPress: () => onMove(note),
        },
        "separator",
        {
            label: "Delete",
            icon: Trash2,
            destructive: true,
            onPress: () => onDelete(note),
        },
    ];

    return (
        <ContextMenu
            visible={visible}
            onClose={onClose}
            items={items}
            title={note.title || "Untitled Note"}
            anchor={anchor}
        />
    );
}
