class TimeUtils {
  /// Group section title based on the creation date of the note.
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

  /// Formats note creation/update time for display in the list card.
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

    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
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
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    }

    final yearStr = date.year.toString();
    final shortYear = yearStr.length >= 4 ? yearStr.substring(2) : yearStr;
    return '${date.month}/${date.day}/$shortYear';
  }
}
