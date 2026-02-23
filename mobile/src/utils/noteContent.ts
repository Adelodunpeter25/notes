const BREAK_TAG_REGEX = /<(\/?(p|div|h1|h2|h3|h4|h5|h6|li|blockquote|pre|br|hr))[^>]*>/gi;
const TAG_REGEX = /<[^>]*>/g;

function htmlToPlainText(html: string): string {
  if (!html) return "";

  // 1. Replace block-level tags and breaks with newlines
  let text = html.replace(BREAK_TAG_REGEX, "\n");

  // 2. Remove all remaining tags
  text = text.replace(TAG_REGEX, " ");

  // 3. Decode common HTML entities
  text = text
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\u00a0/g, " ");

  return text;
}

function getMeaningfulLines(text: string): string[] {
  return text
    .split("\n")
    .map(line => line.trim())
    .filter(line => line.length > 0);
}

export function deriveNoteTitleFromHtml(html: string): string {
  const lines = getMeaningfulLines(htmlToPlainText(html));
  const title = lines[0] || "Untitled";
  return title.length > 100 ? title.substring(0, 100) + "..." : title;
}

export function deriveNotePreviewFromHtml(html: string): string {
  const lines = getMeaningfulLines(htmlToPlainText(html));
  // Skip the title line and join the rest with spaces
  if (lines.length <= 1) return "";
  return lines.slice(1).join(" ").trim();
}
