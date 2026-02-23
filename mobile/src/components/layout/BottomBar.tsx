import { Pressable, Text, View } from "react-native";
import { Folder, NotebookText } from "lucide-react-native";

type BottomTab = "notes" | "folders";

type BottomBarProps = {
  activeTab: BottomTab;
  onChangeTab: (tab: BottomTab) => void;
};

export function BottomBar({ activeTab, onChangeTab }: BottomBarProps) {
  return (
    <View className="border-t border-border bg-surface px-2 pb-2 pt-1">
      <View className="flex-row">
      <Pressable
        onPress={() => onChangeTab("notes")}
        className={[
          "flex-1 items-center justify-center rounded-xl py-2",
          activeTab === "notes" ? "bg-surfaceSecondary/60" : "",
        ].join(" ")}
      >
        <NotebookText
          size={18}
          color={activeTab === "notes" ? "#eab308" : "#a0a0a0"}
          strokeWidth={2.2}
        />
        <Text
          className={[
            "mt-1 text-[12px]",
            activeTab === "notes" ? "font-semibold text-accent" : "text-textMuted",
          ].join(" ")}
        >
          Notes
        </Text>
      </Pressable>

      <Pressable
        onPress={() => onChangeTab("folders")}
        className={[
          "ml-2 flex-1 items-center justify-center rounded-xl py-2",
          activeTab === "folders" ? "bg-surfaceSecondary/60" : "",
        ].join(" ")}
      >
        <Folder
          size={18}
          color={activeTab === "folders" ? "#eab308" : "#a0a0a0"}
          strokeWidth={2.2}
        />
        <Text
          className={[
            "mt-1 text-[12px]",
            activeTab === "folders" ? "font-semibold text-accent" : "text-textMuted",
          ].join(" ")}
        >
          Folders
        </Text>
      </Pressable>
      </View>
    </View>
  );
}
