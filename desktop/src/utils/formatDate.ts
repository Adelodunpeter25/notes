import { format, isToday, isYesterday, parseISO } from "date-fns";

export function formatNoteDate(value?: string): string {
  if (!value) {
    return "";
  }

  const parsed = parseISO(value);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  if (isToday(parsed)) {
    return format(parsed, "h:mm a");
  }

  if (isYesterday(parsed)) {
    return "Yesterday";
  }

  return format(parsed, "MMM d, yyyy");
}

export function formatNoteDateTime(value?: string): string {
  if (!value) {
    return "";
  }

  const parsed = parseISO(value);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  return format(parsed, "d MMMM yyyy 'at' h:mm a");
}

export function formatDate(value?: string | number | Date): string {
  if (!value) return "";
  const date = typeof value === "string" ? parseISO(value) : new Date(value);
  if (isNaN(date.getTime())) return "";
  
  if (isToday(date)) return "Today";
  if (isYesterday(date)) return "Yesterday";
  return format(date, "dd-MM-yyyy");
}
