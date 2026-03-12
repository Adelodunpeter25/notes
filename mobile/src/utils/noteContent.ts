const LINE_BREAK_TAG_REGEX = /<(\/p|\/div|\/h[1-6]|br)\s*>/gi;
const TAG_REGEX = /<[^>]*>/g;

function decodeEntities(value: string): string {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'")
    .replace(/\u00a0/g, " ");
}

function toLines(content: string): string[] {
  const normalizedHtml = (content || "")
    .replace(LINE_BREAK_TAG_REGEX, "\n")
    .replace(/<li[^>]*>/gi, "\n")
    .replace(/<blockquote[^>]*>/gi, "\n")
    .replace(/<pre[^>]*>/gi, "\n")
    .replace(/<\/li>/gi, "")
    .replace(/<\/blockquote>/gi, "")
    .replace(/<\/pre>/gi, "");

  const text = decodeEntities(normalizedHtml.replace(TAG_REGEX, " "));

  return text
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean);
}

export function deriveNoteTitleFromHtml(content: string): string {
  const lines = toLines(content);
  const firstLine = lines[0] || "Untitled";
  return firstLine.length > 100 ? `${firstLine.slice(0, 100)}…` : firstLine;
}

export function deriveNotePreviewFromHtml(content: string): string {
  const lines = toLines(content);
  const previewSource = lines.slice(1).join(" ").trim() || lines[0] || "";
  return previewSource;
}

export function hasMeaningfulHtmlContent(content: string): boolean {
  return toLines(content).length > 0;
}

export function isEmptyDraftNote(note: { title?: string; content?: string; isPinned?: boolean }): boolean {
  const normalizedTitle = (note.title || "").trim();
  const hasContent = hasMeaningfulHtmlContent(note.content || "");
  return !note.isPinned && !hasContent && (normalizedTitle === "" || normalizedTitle === "Untitled");
}
