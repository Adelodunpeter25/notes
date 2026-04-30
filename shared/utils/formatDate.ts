function parseDate(value: string): Date {
  return new Date(value);
}

function isToday(date: Date): boolean {
  const now = new Date();
  return (
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  );
}

function isYesterday(date: Date): boolean {
  const now = new Date();
  const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
  return (
    date.getFullYear() === yesterday.getFullYear() &&
    date.getMonth() === yesterday.getMonth() &&
    date.getDate() === yesterday.getDate()
  );
}

function formatTime(date: Date): string {
  return new Intl.DateTimeFormat(undefined, {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(date);
}

function formatMonthDayYear(date: Date): string {
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

function formatFullDateTime(date: Date): string {
  const day = date.getDate();
  const month = new Intl.DateTimeFormat(undefined, { month: "long" }).format(date);
  const year = date.getFullYear();
  return `${day} ${month} ${year} at ${formatTime(date)}`;
}

function formatDayMonthYearDashed(date: Date): string {
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const year = date.getFullYear();
  return `${day}-${month}-${year}`;
}

export function formatNoteDate(value?: string): string {
  if (!value) {
    return "";
  }

  const parsed = parseDate(value);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  if (isToday(parsed)) {
    return formatTime(parsed);
  }

  if (isYesterday(parsed)) {
    return "Yesterday";
  }

  return formatMonthDayYear(parsed);
}

export function formatNoteDateTime(value?: string): string {
  if (!value) {
    return "";
  }

  const parsed = parseDate(value);
  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  return formatFullDateTime(parsed);
}

export function formatDate(value?: string | number | Date): string {
  if (!value) return "";
  const date = typeof value === "string" ? parseDate(value) : new Date(value);
  if (isNaN(date.getTime())) return "";

  if (isToday(date)) return "Today";
  if (isYesterday(date)) return "Yesterday";
  return formatDayMonthYearDashed(date);
}
