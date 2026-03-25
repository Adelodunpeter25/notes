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

    return format(parsed, "dd-MM-yyyy");
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

export const formatDate = formatNoteDate;
