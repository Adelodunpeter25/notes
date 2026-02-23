import type { Note } from "@shared/notes";

export function deriveNoteTitleFromHtml(content: string): string {
  if (!content) {
    return "Untitled";
  }

  const doc = new DOMParser().parseFromString(content, "text/html");
  const text = (doc.body.textContent || "").trim();
  const firstLine = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean);

  return firstLine || "Untitled";
}

export function hasMeaningfulHtmlContent(content: string): boolean {
  if (!content) {
    return false;
  }

  const doc = new DOMParser().parseFromString(content, "text/html");
  const text = (doc.body.textContent || "")
    .replace(/\u00a0/g, " ")
    .trim();

  return text.length > 0;
}

export function isEmptyDraftNote(note: Pick<Note, "title" | "content" | "isPinned">): boolean {
  const normalizedTitle = (note.title || "").trim();
  const hasContent = hasMeaningfulHtmlContent(note.content || "");

  return !note.isPinned && !hasContent && (normalizedTitle === "" || normalizedTitle === "Untitled");
}

