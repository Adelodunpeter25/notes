import { Pressable, Text, View } from "react-native";
import { CheckSquare, Folder, NotebookPen, Trash2, Settings } from "lucide-react-native";

type BottomTab = "notes" | "folders" | "tasks" | "trash" | "settings";

type BottomBarProps = {
  activeTab: BottomTab;
  onChangeTab: (tab: BottomTab) => void;
};

const TABS = [
  { key: "notes", label: "Notes", Icon: NotebookPen },
  { key: "folders", label: "Folders", Icon: Folder },
  { key: "tasks", label: "Tasks", Icon: CheckSquare },
  { key: "trash", label: "Trash", Icon: Trash2 },
  { key: "settings", label: "Settings", Icon: Settings },
] as const;

export function BottomBar({ activeTab, onChangeTab }: BottomBarProps) {
  return (
    <View className="border-t border-border bg-surface px-2 pb-2 pt-1">
      <View className="flex-row">
        {TABS.map(({ key, label, Icon }, i) => (
          <Pressable
            key={key}
            onPress={() => onChangeTab(key)}
            className={[
              "flex-1 items-center justify-center rounded-xl py-2",
              i > 0 ? "ml-1.5" : "",
              activeTab === key ? "bg-surfaceSecondary/60" : "",
            ].join(" ")}
          >
            <Icon size={18} color={activeTab === key ? "#eab308" : "#a0a0a0"} strokeWidth={2.2} />
            <Text className={["mt-1 text-[11px]", activeTab === key ? "font-semibold text-accent" : "text-textMuted"].join(" ")}>
              {label}
            </Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}
