import { Text } from "react-native";

type EditorPreviewProps = {
  content: string;
};

function stripHtml(content: string): string {
  return content
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
}

export function EditorPreview({ content }: EditorPreviewProps) {
  const preview = stripHtml(content);

  if (!preview) {
    return <Text className="text-[14px] text-textMuted">No additional text</Text>;
  }

  return (
    <Text className="text-[14px] text-textMuted" numberOfLines={1}>
      {preview}
    </Text>
  );
}
