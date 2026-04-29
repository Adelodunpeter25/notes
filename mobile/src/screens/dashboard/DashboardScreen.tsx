import { Text, View, Animated, Easing, Pressable } from "react-native";
import { useEffect, useRef, useState } from "react";
import { useNavigation, useFocusEffect } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { PenLine, WifiOff, RefreshCw, FolderPlus, Settings } from "lucide-react-native";
import { useNetInfo } from "@react-native-community/netinfo";
import { useCallback } from "react";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { FolderList, FolderContextMenu, FolderModal } from "@/components/notes";
import { ConfirmDialog, InlineSearchBar, type ContextMenuItem } from "@/components/common";
import { useDashboardData, useSync } from "@/hooks";
import type { AppStackParamList } from "@/navigation/types";
import type { Folder } from "@shared/folders";
import { isEmptyDraftNote } from "@shared-utils/noteContent";
import { useDeleteNoteMutation } from "@/hooks";

type Navigation = StackNavigationProp<AppStackParamList, "Dashboard">;

export function DashboardScreen() {
  const navigation = useNavigation<Navigation>();
  const dashboard = useDashboardData();
  const { syncNow, isSyncing } = useSync({ auto: true });
  const netInfo = useNetInfo();
  const [menuFolder, setMenuFolder] = useState<Folder | null>(null);
  const [menuAnchor, setMenuAnchor] = useState<{ x: number; y: number } | null>(null);
  const [folderToDelete, setFolderToDelete] = useState<Folder | null>(null);
  const [folderToRename, setFolderToRename] = useState<Folder | null>(null);
  const [isCreateFolderOpen, setIsCreateFolderOpen] = useState(false);
  const spinAnim = useRef(new Animated.Value(0)).current;
  const deleteNoteMutation = useDeleteNoteMutation();
  const [folderSearch, setFolderSearch] = useState("");

  // Clean up empty notes when dashboard is focused
  useFocusEffect(
    useCallback(() => {
      const cleanupEmptyNotes = async () => {
        const emptyNotes = dashboard.notes.filter((note) =>
          isEmptyDraftNote({ title: note.title, content: note.content, isPinned: note.isPinned })
        );
        for (const note of emptyNotes) {
          try {
            await deleteNoteMutation.mutateAsync(note.id);
          } catch (error) {
            console.error("Failed to delete empty note:", error);
          }
        }
      };
      void cleanupEmptyNotes();
    }, [dashboard.notes, deleteNoteMutation])
  );

  useEffect(() => {
    if (!isSyncing) {
      spinAnim.stopAnimation();
      spinAnim.setValue(0);
      return;
    }

    const animation = Animated.loop(
      Animated.timing(spinAnim, {
        toValue: 1,
        duration: 900,
        easing: Easing.linear,
        useNativeDriver: true,
      }),
    );

    animation.start();

    return () => {
      animation.stop();
      spinAnim.setValue(0);
    };
  }, [isSyncing, spinAnim]);

  const spin = spinAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ["0deg", "360deg"],
  });

  const handleCreateNote = async () => {
    try {
      const note = await dashboard.createNote();
      navigation.navigate("Editor", { noteId: note.id, note });
    } catch (error) {
      console.error("Failed to create note:", error);
    }
  };

  const handleCreateFolder = async (name: string) => {
    await dashboard.createFolder(name);
    setIsCreateFolderOpen(false);
  };

  const handleDeleteFolder = async () => {
    if (!folderToDelete) return;
    await dashboard.deleteFolder(folderToDelete.id);
    setFolderToDelete(null);
  };

  const handleRenameFolder = async (name: string) => {
    if (!folderToRename) return;
    await dashboard.renameFolder(folderToRename.id, name);
    setFolderToRename(null);
  };

  const filteredFolders = dashboard.folders.filter(f => 
    f.name.toLowerCase().includes(folderSearch.toLowerCase())
  );

  return (
    <ScreenContainer>
      <View className="flex-row items-center justify-between px-4 py-3 pb-1">
        <View className="flex-row items-center">
          <Text className="text-3xl font-bold text-text">
            Folders
          </Text>
          {netInfo.isConnected === false && (
            <View className="ml-3 flex-row items-center rounded-full bg-danger/20 px-2 py-1">
              <WifiOff size={12} color="#ff4444" />
              <Text className="ml-1 text-[11px] font-medium text-danger uppercase tracking-wider">
                Offline
              </Text>
            </View>
          )}
        </View>
        <View className="flex-row items-center">
          <Pressable
            onPress={() => setIsCreateFolderOpen(true)}
            hitSlop={10}
            className="rounded-md p-1.5 mr-1"
          >
            <FolderPlus size={22} color="#eab308" />
          </Pressable>
          <Pressable
            onPress={() => {
              void syncNow();
            }}
            disabled={isSyncing}
            hitSlop={10}
            className="rounded-full p-1.5 mr-1"
          >
            <Animated.View style={{ transform: [{ rotate: isSyncing ? spin : "0deg" }] }}>
              <RefreshCw size={20} color={isSyncing ? "#a0a0a0" : "#eab308"} />
            </Animated.View>
          </Pressable>
          <Pressable
            onPress={() => navigation.navigate("Settings")}
            hitSlop={10}
            className="rounded-md p-1.5"
          >
            <Settings size={22} color="#eab308" />
          </Pressable>
        </View>
      </View>

      <InlineSearchBar
        value={folderSearch}
        onChangeText={setFolderSearch}
        placeholder="Search Folders"
      />

      <View className="flex-1 px-1 pb-4">
        <FolderList
          folders={filteredFolders}
          allNotesCount={dashboard.notes.length}
          trashCount={dashboard.trashedNotes?.length ?? 0}
          isLoading={dashboard.isFoldersLoading}
          refreshing={dashboard.isFoldersRefreshing}
          onRefresh={() => {
            void dashboard.refetchFolders();
          }}
          onLongPressFolder={(folder, event) => {
            setMenuAnchor({ x: event.nativeEvent.pageX, y: event.nativeEvent.pageY });
            setMenuFolder(folder);
          }}
          onSelectFolder={(folder) => {
            if (folder === 'all') {
              navigation.navigate("FolderDetails", {
                folderId: 'all',
                folderName: 'All Notes',
              });
            } else {
              navigation.navigate("FolderDetails", {
                folderId: folder.id,
                folderName: folder.name,
              });
            }
          }}
          onSelectTrash={() => {
            navigation.navigate("Trash");
          }}
        />
      </View>

      <Pressable
        onPress={handleCreateNote}
        disabled={dashboard.isCreatingNote}
        className="absolute bottom-8 right-8 h-[60px] w-[60px] items-center justify-center rounded-full bg-accent shadow-lg active:scale-95"
        style={{
          shadowColor: "#000",
          shadowOffset: { width: 0, height: 4 },
          shadowOpacity: 0.3,
          shadowRadius: 5,
          elevation: 8,
        }}
      >
        <PenLine size={24} color="#000000" />
      </Pressable>

      <FolderContextMenu
        visible={!!menuFolder}
        folder={menuFolder}
        anchor={menuAnchor}
        onClose={() => {
          setMenuFolder(null);
          setMenuAnchor(null);
        }}
        onRename={(folder) => {
          setFolderToRename(folder);
          setMenuFolder(null);
          setMenuAnchor(null);
        }}
        onDelete={(folder) => {
          setFolderToDelete(folder);
          setMenuFolder(null);
          setMenuAnchor(null);
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

      <FolderModal
        mode="edit"
        visible={!!folderToRename}
        initialName={folderToRename?.name}
        loading={dashboard.isRenamingFolder}
        onCancel={() => setFolderToRename(null)}
        onSave={handleRenameFolder}
      />

      <FolderModal
        mode="create"
        visible={isCreateFolderOpen}
        loading={dashboard.isCreatingFolder}
        onCancel={() => setIsCreateFolderOpen(false)}
        onSave={handleCreateFolder}
      />
    </ScreenContainer>
  );
}
