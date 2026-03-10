import React from "react";
import { View, Text, Pressable, TouchableOpacity } from "react-native";
import { Circle, CheckCircle2, Trash2, Calendar as CalendarIcon } from "lucide-react-native";
import { Swipeable } from "react-native-gesture-handler";
import { forwardRef } from "react";
import type { Task } from "@shared/tasks";
import { cn } from "@/utils/cn";
import { formatDate } from "@/utils/formatDate";

type TaskItemProps = {
  task: Task;
  onToggle: (task: Task) => void;
  onDelete: (task: Task) => void;
  onPress: (task: Task) => void;
};

export const TaskItem = forwardRef<Swipeable, TaskItemProps>(({ task, onToggle, onDelete, onPress }, ref) => {
  const renderRightActions = () => (
    <View className="w-20 bg-danger items-center justify-center">
      <Pressable onPress={() => onDelete(task)}>
        <Trash2 size={24} color="#ffffff" />
      </Pressable>
    </View>
  );

  return (
    <Swipeable
      ref={ref}
      renderRightActions={renderRightActions}
      onSwipeableOpen={(direction) => {
        if (direction === "right") {
          onDelete(task);
        }
      }}
      friction={2}
      rightThreshold={40}
      overshootRight={false}
    >
      <TouchableOpacity
        onPress={() => onPress(task)}
        activeOpacity={0.7}
        className={cn(
          "mx-3 my-1.5 flex-row items-center rounded-2xl border border-border/40 bg-surfaceSecondary/40 px-4 py-4 shadow-sm",
          task.isCompleted && "opacity-60 bg-surface"
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
            <View className="mt-1.5 flex-row items-center justify-between">
              <View className="flex-1 flex-row items-center mr-2">
                {task.description ? (
                  <Text
                    className="text-[13px] text-textMuted flex-1"
                    numberOfLines={1}
                  >
                    {task.description}
                  </Text>
                ) : null}
              </View>
              <View className="items-end">
                {task.dueDate && (
                  <View className="flex-row items-center bg-accent/10 px-1.5 py-0.5 rounded-md mb-1">
                    <CalendarIcon size={10} color="#eab308" className="mr-1" />
                    <Text className="text-[10px] text-accent font-semibold">
                      {formatDate(task.dueDate)}
                    </Text>
                  </View>
                )}
                <Text className="text-[10px] text-textMuted/40">
                  {formatDate(task.createdAt)}
                </Text>
              </View>
            </View>
        </View>
      </TouchableOpacity>
    </Swipeable>
  );
});
