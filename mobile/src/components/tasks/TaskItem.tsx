import React from "react";
import { View, Text, Pressable, TouchableOpacity } from "react-native";
import { Circle, CheckCircle2, Trash2 } from "lucide-react-native";
import { Swipeable } from "react-native-gesture-handler";
import type { Task } from "@shared/tasks";
import { cn } from "@/utils/cn";
import { formatDate } from "@/utils/formatDate";

type TaskItemProps = {
  task: Task;
  onToggle: (task: Task) => void;
  onDelete: (task: Task) => void;
  onPress: (task: Task) => void;
};

export function TaskItem({ task, onToggle, onDelete, onPress }: TaskItemProps) {
  const renderRightActions = () => (
    <View className="w-20 bg-danger items-center justify-center">
      <Pressable onPress={() => onDelete(task)}>
        <Trash2 size={24} color="#ffffff" />
      </Pressable>
    </View>
  );

  return (
    <Swipeable renderRightActions={renderRightActions} friction={2} rightThreshold={40} overshootRight={false}>
      <TouchableOpacity
        onPress={() => onPress(task)}
        activeOpacity={0.7}
        className={cn(
          "flex-row items-center px-4 py-4 bg-surface border-b border-border/50",
          task.isCompleted && "opacity-60"
        )}
      >
        <Pressable
          onPress={() => onToggle(task)}
          className="mr-4 h-6 w-6 items-center justify-center"
        >
          {task.isCompleted ? (
            <CheckCircle2 size={24} color="#eab308" />
          ) : (
            <Circle size={24} color="#6f6f6f" />
          )}
        </Pressable>

        <View className="flex-1">
          <Text
            className={cn(
              "text-[16px] font-medium text-text",
              task.isCompleted && "line-through text-textMuted"
            )}
            numberOfLines={1}
          >
            {task.title || "Untitled Task"}
          </Text>
          {(task.description || task.dueDate) && (
            <View className="mt-1 flex-row items-center">
              {task.description ? (
                <Text
                  className="text-[13px] text-textMuted flex-1"
                  numberOfLines={1}
                >
                  {task.description}
                </Text>
              ) : null}
              {task.dueDate && (
                <Text className="ml-2 text-[12px] text-accent/80 font-medium">
                  {formatDate(task.dueDate)}
                </Text>
              )}
            </View>
          )}
        </View>
      </TouchableOpacity>
    </Swipeable>
  );
}
