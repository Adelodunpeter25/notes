import { useEffect, useState } from "react";
import { Modal, Pressable, Text, TouchableWithoutFeedback, View } from "react-native";

import { Button, Input } from "@/components/common";

type RenameFolderModalProps = {
  visible: boolean;
  initialName: string;
  loading?: boolean;
  onCancel: () => void;
  onSave: (name: string) => void;
};

export function RenameFolderModal({
  visible,
  initialName,
  loading = false,
  onCancel,
  onSave,
}: RenameFolderModalProps) {
  const [name, setName] = useState(initialName);

  useEffect(() => {
    setName(initialName);
  }, [initialName, visible]);

  const trimmed = name.trim();
  const isDisabled = !trimmed || trimmed === initialName.trim() || loading;

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onCancel}>
      <TouchableWithoutFeedback onPress={onCancel}>
        <View className="flex-1 items-center justify-center bg-black/60 px-6">
          <TouchableWithoutFeedback>
            <View className="w-full max-w-[340px] rounded-2xl border border-border/50 bg-surface p-5">
              <Text className="mb-3 text-lg font-semibold text-text">Rename Folder</Text>
              <Input
                value={name}
                onChangeText={setName}
                placeholder="Folder name"
                autoFocus
                returnKeyType="done"
                onSubmitEditing={() => {
                  if (!isDisabled) onSave(trimmed);
                }}
              />
              <View className="mt-2 flex-row justify-end gap-2">
                <Pressable onPress={onCancel} className="rounded-lg px-3 py-2">
                  <Text className="text-textMuted">Cancel</Text>
                </Pressable>
                <Button
                  title="Save"
                  onPress={() => onSave(trimmed)}
                  disabled={isDisabled}
                  loading={loading}
                  className="px-4 py-2"
                />
              </View>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );
}

