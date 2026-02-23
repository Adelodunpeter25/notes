import { useMemo } from "react";

type EditorPreviewProps = {
    content?: string;
    maxLength?: number;
};

export function EditorPreview({ content, maxLength = 40 }: EditorPreviewProps) {
    const snippet = useMemo(() => {
        if (!content) return "No additional text";

        const normalizedHtml = content
            .replace(/<(\/p|\/div|\/h[1-6]|br)\s*>/gi, "\n")
            .replace(/&nbsp;/g, " ");

        const doc = new DOMParser().parseFromString(normalizedHtml, "text/html");
        const text = (doc.body.textContent || "").trim();
        if (!text) return "No additional text";

        const lines = text
            .split(/\r?\n/)
            .map((line) => line.replace(/\s+/g, " ").trim())
            .filter(Boolean);

        const previewSource = lines.slice(1).join(" ").trim() || lines[0];
        return previewSource.length > maxLength
            ? `${previewSource.slice(0, maxLength)}…`
            : previewSource;
    }, [content, maxLength]);

    return <span className="truncate opacity-70 font-normal">{snippet}</span>;
}
