const BREAK_TAG_REGEX = /<(\/?(p|div|h1|h2|h3|h4|h5|h6|li|blockquote))[^>]*>/gi;
const BR_REGEX = /<br\s*\/?>/gi;
const TAG_REGEX = /<[^>]*>/g;
const NBSP_REGEX = /&nbsp;/gi;
const MULTI_NEWLINE_REGEX = /\n{3,}/g;

function htmlToPlainText(html: string): string {
  return (html || "")
    .replace(BR_REGEX, "\n")
    .replace(BREAK_TAG_REGEX, "\n")
    .replace(TAG_REGEX, " ")
    .replace(NBSP_REGEX, " ")
    .replace(/\r/g, "")
    .replace(MULTI_NEWLINE_REGEX, "\n\n")
    .trim();
}

function meaningfulLines(plainText: string): string[] {
  return plainText
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

export function deriveNoteTitleFromHtml(html: string): string {
  const lines = meaningfulLines(htmlToPlainText(html));
  return lines[0] || "Untitled";
}

export function deriveNotePreviewFromHtml(html: string): string {
  const lines = meaningfulLines(htmlToPlainText(html));
  return lines.slice(1).join(" ").trim();
}

