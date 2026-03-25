import React from "react";
import { View, Text, Pressable, TouchableOpacity } from "react-native";
import { Circle, CheckCircle2, Trash2, Calendar as CalendarIcon } from "lucide-react-native";
import type { Task } from "@shared/tasks";
import { cn } from "@shared-utils/cn";
import { formatDate } from "@shared-utils/formatDate";

type TaskItemProps = {
  task: Task;
  onToggle: (task: Task) => void;
  onDelete: (task: Task) => void;
  onPress: (task: Task) => void;
};

export function TaskItem({ task, onToggle, onDelete, onPress }: TaskItemProps) {
  return (
    <Pressable
      onPress={() => onPress(task)}
      className={cn(
        "mx-3 my-1.5 flex-row items-center rounded-2xl border border-border/40 bg-surfaceSecondary/40 px-4 py-4 shadow-sm",
        task.isCompleted && "opacity-60 bg-surface"
      )}
      style={({ pressed }) => [{ opacity: pressed ? 0.7 : (task.isCompleted ? 0.6 : 1) }]}
    >
      <Pressable
        onPress={() => onToggle(task)}
        hitSlop={16}
        className="mr-4 h-6 w-6 items-center justify-center"
      >
        {task.isCompleted ? (
          <CheckCircle2 size={24} color="#eab308" />
        ) : (
          <Circle size={24} color="#6f6f6f" />
        )}
      </Pressable>

      <View className="flex-1">
        <View className="flex-row items-center justify-between">
          <Text
            className={cn(
              "text-[16px] font-medium text-text flex-1 mr-2",
              task.isCompleted && "line-through text-textMuted"
            )}
            numberOfLines={1}
          >
            {task.title || "Untitled Task"}
          </Text>
          {task.dueDate && (
            <View className="bg-accent/10 px-1.5 py-0.5 rounded-md">
              <Text className="text-[10px] text-accent font-semibold">
                {formatDate(task.dueDate)}
              </Text>
            </View>
          )}
        </View>

        {task.description ? (
          <Text
            className="mt-0.5 text-[13px] text-textMuted"
            numberOfLines={1}
          >
            {task.description}
          </Text>
        ) : null}

        <Text className="mt-1 text-[10px] text-textMuted/30">
          {formatDate(task.createdAt)}
        </Text>
      </View>

      <Pressable 
        onPress={(e) => {
          e.stopPropagation();
          onDelete(task);
        }} 
        hitSlop={20} 
        className="ml-3 p-1"
      >
        <Trash2 size={20} color="#ff4444" />
      </Pressable>
    </Pressable>
  );
}
