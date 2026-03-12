import React from "react";
import { FlatList, View, Text } from "react-native";
import { TaskItem } from "./TaskItem";
import type { Task } from "@shared/tasks";
import { Skeleton } from "@/components/common";
import { useState, useRef } from "react";
import type { Swipeable } from "react-native-gesture-handler";

type TaskListProps = {
  tasks: Task[];
  isLoading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  onToggleTask: (task: Task) => void;
  onDeleteTask: (task: Task) => void;
  onSelectTask: (task: Task) => void;
  emptyText?: string;
};

export function TaskList({
  tasks,
  isLoading,
  refreshing,
  onRefresh,
  onToggleTask,
  onDeleteTask: propOnDeleteTask,
  onSelectTask,
  emptyText = "All tasks completed! Enjoy your day.",
}: TaskListProps) {
  const swipeableRefs = useRef<{ [key: string]: Swipeable | null }>({});
  if (isLoading) {
    return (
      <View className="px-4 pt-2">
        <Skeleton className="mb-2 h-20 w-full" />
        <Skeleton className="mb-2 h-20 w-full" />
        <Skeleton className="h-20 w-full" />
      </View>
    );
  }

  if (tasks.length === 0) {
    return (
      <View className="items-center justify-center px-6 py-20">
        <Text className="text-sm text-textMuted text-center">{emptyText}</Text>
      </View>
    );
  }

  return (
    <>
      <FlatList
        data={tasks}
        keyExtractor={(item) => item.id}
      refreshing={refreshing}
      onRefresh={onRefresh}
      renderItem={({ item }) => (
        <TaskItem
          ref={(ref) => { swipeableRefs.current[item.id] = ref; }}
          task={item}
          onToggle={onToggleTask}
          onDelete={(task) => {
             void propOnDeleteTask(task);
          }}
          onPress={onSelectTask}
        />
      )}
      contentContainerStyle={{ paddingBottom: 100, paddingTop: 8 }}
    />
    </>
  );
}
