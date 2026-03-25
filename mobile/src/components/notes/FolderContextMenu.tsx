import React from "react";
import { Edit2, Trash2 } from "lucide-react-native";
import { ContextMenu, ContextMenuItem } from "@/components/common";
import { Folder } from "@shared/folders";

interface FolderContextMenuProps {
    visible: boolean;
    folder: Folder | null;
    anchor?: { x: number; y: number } | null;
    onClose: () => void;
    onRename: (folder: Folder) => void;
    onDelete: (folder: Folder) => void;
}

export function FolderContextMenu({
    visible,
    folder,
    anchor,
    onClose,
    onRename,
    onDelete,
}: FolderContextMenuProps) {
    if (!folder) return null;

    const items: (ContextMenuItem | "separator")[] = [
        {
            label: "Rename",
            icon: Edit2,
            onPress: () => onRename(folder),
        },
        "separator",
        {
            label: "Delete",
            icon: Trash2,
            destructive: true,
            onPress: () => onDelete(folder),
        },
    ];

    return (
        <ContextMenu
            visible={visible}
            onClose={onClose}
            items={items}
            title={folder.name}
            anchor={anchor}
        />
    );
}
