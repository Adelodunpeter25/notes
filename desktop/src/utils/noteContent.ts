import type { Note } from "@shared/notes";

export function deriveNoteTitleFromHtml(content: string): string {
  if (!content) {
    return "Untitled";
  }

  const doc = new DOMParser().parseFromString(content, "text/html");
  const blockElements = doc.querySelectorAll(
    "h1, h2, h3, h4, h5, h6, p, li, blockquote, pre, code, div",
  );

  for (const element of Array.from(blockElements)) {
    const text = (element.textContent || "").replace(/\u00a0/g, " ").trim();
    if (text) {
      return text;
    }
  }

  const fallbackText = (doc.body.textContent || "").replace(/\u00a0/g, " ").trim();
  return fallbackText || "Untitled";
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
