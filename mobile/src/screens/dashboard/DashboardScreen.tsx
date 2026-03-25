import { Text, View, Alert, Animated, Easing, Pressable } from "react-native";
import { useEffect, useRef, useState } from "react";
import { useNavigation, useFocusEffect } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { Search, PenLine, Plus, WifiOff, RefreshCw, Calendar, List } from "lucide-react-native";
import { useNetInfo } from "@react-native-community/netinfo";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { useCallback } from "react";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { FolderList, NoteList, NoteContextMenu, FolderContextMenu, FolderModal } from "@/components/notes";
import { TaskList, TaskModal, CalendarView } from "@/components/tasks";
import { ConfirmDialog, ContextMenu, type ContextMenuItem } from "@/components/common";
import { BottomBar } from "@/components/layout";
import { useDashboardData, useSync } from "@/hooks";
import type { AppStackParamList } from "@/navigation/types";
import type { Note } from "@shared/notes";
import type { Folder } from "@shared/folders";
import type { Task } from "@shared/tasks";
import { isEmptyDraftNote } from "@shared-utils/noteContent";
import { useDeleteNoteMutation } from "@/hooks";

type Navigation = StackNavigationProp<AppStackParamList, "Dashboard">;

const ACTIVE_TAB_KEY = "@notes/activeTab";

export function DashboardScreen() {
  const navigation = useNavigation<Navigation>();
  const [activeTab, setActiveTab] = useState<"notes" | "folders" | "tasks" | "trash">("notes");
  const [taskView, setTaskView] = useState<"list" | "calendar">("list");
  const dashboard = useDashboardData();
  const { syncNow, isSyncing } = useSync({ auto: false });
  const netInfo = useNetInfo();
  const [menuNote, setMenuNote] = useState<Note | null>(null);
  const [menuFolder, setMenuFolder] = useState<Folder | null>(null);
  const [menuAnchor, setMenuAnchor] = useState<{ x: number; y: number } | null>(null);
  const [folderToDelete, setFolderToDelete] = useState<Folder | null>(null);
  const [noteToDelete, setNoteToDelete] = useState<Note | null>(null);
  const [folderToRename, setFolderToRename] = useState<Folder | null>(null);
  const [noteToMove, setNoteToMove] = useState<Note | null>(null);
  const [isCreateFolderOpen, setIsCreateFolderOpen] = useState(false);
  const [isTaskModalOpen, setIsTaskModalOpen] = useState(false);
  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const [selectedDateTasks, setSelectedDateTasks] = useState<{ date: Date; tasks: Task[] } | null>(null);
  const spinAnim = useRef(new Animated.Value(0)).current;
  const deleteNoteMutation = useDeleteNoteMutation();

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

  // Active tab removed persistence logic

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

  const handlePinNote = async (note: Note) => {
    await dashboard.saveNote(note.id, { isPinned: !note.isPinned });
  };

  const handleDeleteNote = async (note: Note) => {
    setNoteToDelete(note);
  };

  const handleMoveNote = (_note: Note) => {
    if (dashboard.folders.filter((folder) => folder.id !== _note.folderId).length === 0) {
      Alert.alert("No folders", "Create a folder first.");
      return;
    }
    setNoteToMove(_note);
  };

  const handleDeleteFolder = async () => {
    if (!folderToDelete) return;
    await dashboard.deleteFolder(folderToDelete.id);
    setFolderToDelete(null);
  };

  const handleConfirmDeleteNote = async () => {
    if (!noteToDelete) return;
    await dashboard.deleteNote(noteToDelete.id);
    setNoteToDelete(null);
  };

  const handleRenameFolder = async (name: string) => {
    if (!folderToRename) return;
    await dashboard.renameFolder(folderToRename.id, name);
    setFolderToRename(null);
  };

  const moveTargets = dashboard.folders.filter((folder) => folder.id !== noteToMove?.folderId);
  const moveItems: (ContextMenuItem | "separator")[] = moveTargets.map((folder) => ({
    label: folder.name,
    onPress: () => {
      if (!noteToMove) return;
      void dashboard.saveNote(noteToMove.id, { folderId: folder.id });
      setNoteToMove(null);
      setMenuAnchor(null);
    },
  }));

  return (
    <ScreenContainer>
      <View className="flex-row items-center justify-between border-b border-border px-4 py-3">
        <View className="flex-row items-center">
          <Text className="text-xl font-semibold text-text">
            {activeTab === "folders" ? "Folders" : activeTab === "tasks" ? "Tasks" : "Notes"}
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
          {activeTab === "tasks" && (
            <Pressable
              onPress={() => setTaskView(taskView === "list" ? "calendar" : "list")}
              hitSlop={10}
              className="rounded-md p-1.5"
            >
              {taskView === "list" ? (
                <Calendar size={18} color="#eab308" />
              ) : (
                <List size={18} color="#eab308" />
              )}
            </Pressable>
          )}
          <Pressable
            onPress={() => navigation.navigate("Search")}
            hitSlop={10}
            className="rounded-md p-1.5"
          >
            <Search size={18} color="#eab308" />
          </Pressable>
          <Pressable
            onPress={() => {
              void syncNow();
            }}
            disabled={isSyncing}
            hitSlop={10}
            className="ml-1 rounded-full border border-border/60 p-1.5"
          >
            <Animated.View style={{ transform: [{ rotate: isSyncing ? spin : "0deg" }] }}>
              <RefreshCw size={18} color={isSyncing ? "#a0a0a0" : "#eab308"} />
            </Animated.View>
          </Pressable>
        </View>
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
              onLongPressFolder={(folder, event) => {
                setMenuAnchor({ x: event.nativeEvent.pageX, y: event.nativeEvent.pageY });
                setMenuFolder(folder);
              }}
              onSelectFolder={(folder) => {
                navigation.navigate("FolderDetails", {
                  folderId: folder.id,
                  folderName: folder.name,
                });
              }}
            />
          </View>
        ) : activeTab === "tasks" ? (
          <View className="flex-1">
            {taskView === "list" ? (
              <TaskList
                tasks={dashboard.tasks}
                isLoading={dashboard.isTasksLoading}
                refreshing={dashboard.isTasksRefreshing}
                onRefresh={() => {
                  void dashboard.refetchTasks();
                }}
                onToggleTask={(task) => {
                  void dashboard.toggleTask(task);
                }}
                onDeleteTask={(task) => {
                  void dashboard.deleteTask(task.id);
                }}
                onSelectTask={(task) => {
                  setEditingTask(task);
                  setIsTaskModalOpen(true);
                }}
              />
            ) : (
              <CalendarView
                tasks={dashboard.tasks}
                onSelectDate={(date, tasks) => {
                  setSelectedDateTasks({ date, tasks });
                }}
              />
            )}
          </View>
        ) : (
          <View className="flex-1">
            <NoteList
              notes={dashboard.notes}
              folders={dashboard.folders}
              isLoading={dashboard.isNotesLoading}
              refreshing={dashboard.isNotesRefreshing}
              onRefresh={() => {
                void dashboard.refetchNotes();
              }}
              emptyText="No notes yet."
              onSelectNote={(note) => {
                navigation.navigate("Editor", { noteId: note.id, note });
              }}
              onLongPressNote={(note, event) => {
                setMenuAnchor({ x: event.nativeEvent.pageX, y: event.nativeEvent.pageY });
                setMenuNote(note);
              }}
            />
          </View>
        )}
      </View>

      <Pressable
        onPress={() => {
          if (activeTab === "folders") {
            setIsCreateFolderOpen(true);
            return;
          }
          if (activeTab === "tasks") {
            setEditingTask(null);
            setIsTaskModalOpen(true);
            return;
          }
          void handleCreateNote();
        }}
        disabled={
          activeTab === "folders"
            ? dashboard.isCreatingFolder
            : activeTab === "tasks"
            ? dashboard.isCreatingTask
            : dashboard.isCreatingNote
        }
        className="absolute bottom-28 right-8 h-[63px] w-[63px] items-center justify-center rounded-full bg-accent shadow-lg active:scale-95"
      >
        {activeTab === "folders" ? (
          <Plus size={26} color="#000000" />
        ) : activeTab === "tasks" ? (
          <Plus size={26} color="#000000" />
        ) : (
          <PenLine size={24} color="#000000" />
        )}
      </Pressable>

      <BottomBar
        activeTab={activeTab}
        onChangeTab={(tab) => {
          if (tab === "trash") {
            navigation.navigate("Trash");
            return;
          }
          setActiveTab(tab);
        }}
      />

      <NoteContextMenu
        visible={!!menuNote}
        note={menuNote}
        anchor={menuAnchor}
        onClose={() => {
          setMenuNote(null);
        }}
        onPin={handlePinNote}
        onMove={handleMoveNote}
        onDelete={handleDeleteNote}
      />

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

      <ContextMenu
        visible={!!noteToMove}
        anchor={menuAnchor}
        title="Move to Folder"
        items={moveItems}
        onClose={() => {
          setNoteToMove(null);
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

      <ConfirmDialog
        visible={!!noteToDelete}
        title="Delete Note"
        description="Are you sure you want to delete this note?"
        confirmLabel="Delete"
        destructive
        onConfirm={handleConfirmDeleteNote}
        onCancel={() => setNoteToDelete(null)}
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

      <TaskModal
        visible={isTaskModalOpen}
        loading={dashboard.isCreatingTask || dashboard.isUpdatingTask}
        initialTask={editingTask}
        onCancel={() => {
          setIsTaskModalOpen(false);
          setEditingTask(null);
        }}
        onDelete={(task) => {
          setIsTaskModalOpen(false);
          setEditingTask(null);
          void dashboard.deleteTask(task.id);
        }}
        onSave={async (payload) => {
          if (editingTask) {
            await dashboard.updateTask(editingTask.id, {
              title: payload.title,
              description: payload.description,
              dueDate: payload.dueDate,
            });
          } else {
            await dashboard.createTask(payload);
          }
          setIsTaskModalOpen(false);
          setEditingTask(null);
        }}
      />

      <ContextMenu
        visible={!!selectedDateTasks}
        anchor={{ x: 0, y: 0 }}
        title={selectedDateTasks ? `${selectedDateTasks.tasks.length} task${selectedDateTasks.tasks.length !== 1 ? "s" : ""}` : ""}
        items={
          selectedDateTasks?.tasks.map((task) => ({
            label: task.title,
            onPress: () => {
              setEditingTask(task);
              setIsTaskModalOpen(true);
              setSelectedDateTasks(null);
            },
          })) || []
        }
        onClose={() => setSelectedDateTasks(null)}
      />
    </ScreenContainer>
  );
}
