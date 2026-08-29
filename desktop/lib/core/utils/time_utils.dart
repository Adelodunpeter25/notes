class TimeUtils {
  /// Group section title based on the note's last update date.
  static String getNoteSection(DateTime date) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));

    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate.isAtSameMomentAs(todayMidnight)) {
      return 'Today';
    }

    if (itemDate.isAtSameMomentAs(yesterdayMidnight)) {
      return 'Yesterday';
    }

    // "This Week" (within the last 7 days, excluding today/yesterday)
    final sevenDaysAgo = todayMidnight.subtract(const Duration(days: 7));
    if (itemDate.isAfter(sevenDaysAgo)) {
      return 'This Week';
    }

    // "Last Month" (within the last 30 days, excluding the above)
    final thirtyDaysAgo = todayMidnight.subtract(const Duration(days: 30));
    if (itemDate.isAfter(thirtyDaysAgo)) {
      return 'Last Month';
    }

    // "Last Year" (within the last 365 days, excluding the above)
    final yearAgo = todayMidnight.subtract(const Duration(days: 365));
    if (itemDate.isAfter(yearAgo)) {
      return 'Last Year';
    }

    return 'Older';
  }

  /// Formats note time for display in the list.
  ///
  /// - Today: "3:45 PM"
  /// - Yesterday: "Yesterday"
  /// - Within last 7 days: Day of week (e.g., "Monday")
  /// - Older: Date format "MM/DD/YY" (e.g., "6/4/26")
  static String formatCardTime(DateTime date) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $ampm';

    if (itemDate.isAtSameMomentAs(todayMidnight)) {
      return timeStr;
    }

    if (itemDate.isAtSameMomentAs(yesterdayMidnight)) {
      return 'Yesterday';
    }

    final sevenDaysAgo = todayMidnight.subtract(const Duration(days: 7));
    if (itemDate.isAfter(sevenDaysAgo)) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[date.weekday - 1];
    }

    final yearStr = date.year.toString();
    final shortYear = yearStr.length >= 4 ? yearStr.substring(2) : yearStr;
    return '${date.month}/${date.day}/$shortYear';
  }

  /// Formats a date for the editor header: "4 Jun 2026 at 3:45 PM".
  static String formatEditorHeader(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute $ampm';
  }
}
