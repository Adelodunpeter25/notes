import { Text, View, Alert } from "react-native";
import { Pressable } from "react-native";
import { useState } from "react";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { Search, Plus } from "lucide-react-native";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { FolderList, NoteList, NoteContextMenu, FolderContextMenu } from "@/components/notes";
import { ConfirmDialog } from "@/components/common";
import { BottomBar } from "@/components/layout";
import { useDashboardData } from "@/hooks";
import type { AppStackParamList } from "@/navigation/types";
import type { Note } from "@shared/notes";
import type { Folder } from "@shared/folders";

type Navigation = StackNavigationProp<AppStackParamList, "Dashboard">;

export function DashboardScreen() {
  const navigation = useNavigation<Navigation>();
  const [activeTab, setActiveTab] = useState<"notes" | "folders">("notes");
  const dashboard = useDashboardData();
  const [menuNote, setMenuNote] = useState<Note | null>(null);
  const [menuFolder, setMenuFolder] = useState<Folder | null>(null);
  const [folderToDelete, setFolderToDelete] = useState<Folder | null>(null);

  const handleCreateNote = async () => {
    try {
      const note = await dashboard.createNote();
      navigation.navigate("Editor", { noteId: note.id });
    } catch (error) {
      console.error("Failed to create note:", error);
    }
  };

  const handlePinNote = async (note: Note) => {
    await dashboard.saveNote(note.id, { isPinned: !note.isPinned });
  };

  const handleDeleteNote = async (note: Note) => {
    await dashboard.deleteNote(note.id);
  };

  const handleMoveNote = (_note: Note) => {
    Alert.alert("Not yet", "Move to folder will be added next.");
  };

  const handleDeleteFolder = async () => {
    if (!folderToDelete) return;
    await dashboard.deleteFolder(folderToDelete.id);
    setFolderToDelete(null);
  };

  return (
    <ScreenContainer>
      <View className="flex-row items-center justify-between border-b border-border px-4 py-3">
        <Text className="text-xl font-semibold text-text">
          {activeTab === "folders" ? "Folders" : "Notes"}
        </Text>
        <Pressable onPress={() => navigation.navigate("Search")} className="rounded-md p-1.5">
          <Search size={18} color="#eab308" />
        </Pressable>
      </View>

      <View className="flex-1">
        {activeTab === "folders" ? (
          <View className="flex-1">
            <FolderList
              folders={dashboard.folders}
              isLoading={dashboard.isFoldersLoading}
              refreshing={dashboard.isFoldersRefreshing}
              onRefresh={() => {
                void dashboard.refetchFolders();
              }}
              onLongPressFolder={(folder) => setMenuFolder(folder)}
              onSelectFolder={(folder) => {
                navigation.navigate("FolderDetails", {
                  folderId: folder.id,
                  folderName: folder.name,
                });
              }}
            />
          </View>
        ) : (
          <View className="flex-1">
            <NoteList
              notes={dashboard.notes}
              isLoading={dashboard.isNotesLoading}
              refreshing={dashboard.isNotesRefreshing}
              onRefresh={() => {
                void dashboard.refetchNotes();
              }}
              emptyText="No notes yet."
              onSelectNote={(note) => {
                navigation.navigate("Editor", { noteId: note.id });
              }}
              onLongPressNote={(note) => setMenuNote(note)}
            />
          </View>
        )}
      </View>

      <Pressable
        onPress={handleCreateNote}
        disabled={dashboard.isCreatingNote}
        className="absolute bottom-28 right-8 h-16 w-16 items-center justify-center rounded-full bg-accent shadow-lg active:scale-95"
      >
        <Plus size={32} color="#000000" />
      </Pressable>

      <BottomBar activeTab={activeTab} onChangeTab={setActiveTab} />

      <NoteContextMenu
        visible={!!menuNote}
        note={menuNote}
        onClose={() => setMenuNote(null)}
        onPin={handlePinNote}
        onMove={handleMoveNote}
        onDelete={handleDeleteNote}
      />

      <FolderContextMenu
        visible={!!menuFolder}
        folder={menuFolder}
        onClose={() => setMenuFolder(null)}
        onRename={() => {
          Alert.alert("Not yet", "Rename folder will be added next.");
        }}
        onDelete={(folder) => {
          setFolderToDelete(folder);
          setMenuFolder(null);
        }}
      />

      <ConfirmDialog
        visible={!!folderToDelete}
        title="Delete Folder"
        description="Are you sure you want to delete this folder?"
        confirmLabel="Delete"
        destructive
        onConfirm={handleDeleteFolder}
        onCancel={() => setFolderToDelete(null)}
      />
    </ScreenContainer>
  );
}
