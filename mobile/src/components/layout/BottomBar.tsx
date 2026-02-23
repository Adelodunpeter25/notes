import { Pressable, Text, View } from "react-native";

type BottomTab = "notes" | "folders";

type BottomBarProps = {
  activeTab: BottomTab;
  onChangeTab: (tab: BottomTab) => void;
};

export function BottomBar({ activeTab, onChangeTab }: BottomBarProps) {
  return (
    <View className="flex-row border-t border-border bg-surface px-3 py-2">
      <Pressable
        onPress={() => onChangeTab("notes")}
        className={[
          "flex-1 items-center rounded-lg py-2",
          activeTab === "notes" ? "bg-surfaceSecondary" : "",
        ].join(" ")}
      >
        <Text className={activeTab === "notes" ? "text-text font-semibold" : "text-textMuted"}>
          Notes
        </Text>
      </Pressable>

      <Pressable
        onPress={() => onChangeTab("folders")}
        className={[
          "ml-2 flex-1 items-center rounded-lg py-2",
          activeTab === "folders" ? "bg-surfaceSecondary" : "",
        ].join(" ")}
      >
        <Text className={activeTab === "folders" ? "text-text font-semibold" : "text-textMuted"}>
          Folders
        </Text>
      </Pressable>
    </View>
  );
}
