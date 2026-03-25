import { useEffect, useState } from "react";
import { Modal, Pressable, Text, TouchableWithoutFeedback, View, KeyboardAvoidingView, Platform, TextInput } from "react-native";
import { X } from "lucide-react-native";
import { Button, DatePicker } from "@/components/common";
import type { Task, CreateTaskPayload } from "@shared/tasks";
import { cn } from "@shared-utils/cn";

type TaskModalProps = {
  visible: boolean;
  onCancel: () => void;
  onSave: (payload: CreateTaskPayload) => void;
  loading?: boolean;
  initialTask?: Task | null;
  onDelete?: (task: Task) => void;
};

export function TaskModal({
  visible,
  onCancel,
  onSave,
  onDelete,
  loading = false,
  initialTask,
}: TaskModalProps) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [dueDate, setDueDate] = useState<Date | null>(null);

  useEffect(() => {
    if (initialTask) {
      setTitle(initialTask.title);
      setDescription(initialTask.description);
      setDueDate(initialTask.dueDate ? new Date(initialTask.dueDate) : null);
    } else {
      setTitle("");
      setDescription("");
      setDueDate(null);
    }
  }, [initialTask, visible]);

  const handleSave = () => {
    if (!title.trim()) return;
    onSave({
      title: title.trim(),
      description: description.trim(),
      isCompleted: initialTask?.isCompleted ?? false,
      dueDate: dueDate?.toISOString(),
    });
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onCancel}>
      <TouchableWithoutFeedback onPress={onCancel}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          style={{ flex: 1 }}
          keyboardVerticalOffset={Platform.OS === "ios" ? 24 : 0}
        >
          <View className="flex-1 justify-end bg-black/40">
            <TouchableWithoutFeedback>
              <View className="bg-surface rounded-t-3xl border-t border-border/50 p-6 pt-4">
                <View className="flex-row items-center justify-between mb-4">
                  <Text className="text-xl font-bold text-text">
                    {initialTask ? "Edit Task" : "New Task"}
                  </Text>
                  <Pressable onPress={onCancel} className="p-1">
                    <X size={20} color="#a0a0a0" />
                  </Pressable>
                </View>

                <TextInput
                  value={title}
                  onChangeText={setTitle}
                  placeholder="What needs to be done?"
                  placeholderTextColor="#6f6f6f"
                  autoFocus
                  className="text-[17px] text-text font-medium mb-4 py-2"
                  returnKeyType="next"
                />

                <TextInput
                  value={description}
                  onChangeText={setDescription}
                  placeholder="Add description (optional)"
                  placeholderTextColor="#6f6f6f"
                  multiline
                  className="text-[15px] text-textMuted mb-4 min-h-[60px] max-h-[120px] py-2"
                />

                <DatePicker
                  value={dueDate}
                  onChange={setDueDate}
                  placeholder="Set a deadline"
                  className="mb-8"
                />

                <Button
                  title={initialTask ? "Update Task" : "Create Task"}
                  onPress={handleSave}
                  disabled={!title.trim() || loading}
                  loading={loading}
                  className="rounded-xl py-3.5"
                  textClassName="text-[17px]"
                />

                {initialTask && onDelete && (
                  <Button
                    title="Delete Task"
                    onPress={() => onDelete(initialTask)}
                    variant="outline"
                    className="mt-3 border-danger/30 rounded-xl py-3.5"
                    textClassName="text-danger text-[17px]"
                  />
                )}
                <View style={{ height: Platform.OS === "ios" ? 40 : 20 }} />
              </View>
            </TouchableWithoutFeedback>
          </View>
        </KeyboardAvoidingView>
      </TouchableWithoutFeedback>
    </Modal>
  );
}
