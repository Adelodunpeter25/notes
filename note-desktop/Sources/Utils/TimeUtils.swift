import Foundation

public final class TimeUtils {
    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    public static func stringFromDate(_ date: Date) -> String {
        return isoFormatter.string(from: date)
    }
    
    public static func dateFromString(_ string: String) -> Date? {
        if let date = isoFormatter.date(from: string) {
            return date
        }
        let basicFormatter = ISO8601DateFormatter()
        return basicFormatter.date(from: string)
    }
    
    /// Group section title based on the creation date of the note.
    public static func getNoteSection(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let todayMidnight = calendar.startOfDay(for: now)
        guard let yesterdayMidnight = calendar.date(byAdding: .day, value: -1, to: todayMidnight) else { return "Older" }
        
        let itemDate = calendar.startOfDay(for: date)
        
        if itemDate == todayMidnight {
            return "Today"
        }
        
        if itemDate == yesterdayMidnight {
            return "Yesterday"
        }
        
        // "Previous 7 Days"
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: todayMidnight) else { return "Older" }
        if itemDate >= sevenDaysAgo {
            return "Previous 7 Days"
        }
        
        // "Previous 30 Days"
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: todayMidnight) else { return "Older" }
        if itemDate >= thirtyDaysAgo {
            return "Previous 30 Days"
        }
        
        // Same Year check
        let nowYear = calendar.component(.year, from: now)
        let itemYear = calendar.component(.year, from: date)
        
        if itemYear == nowYear {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM"
            return monthFormatter.string(from: date)
        }
        
        return "\(itemYear)"
    }
    
    /// Formats note creation/update time for display in the list card.
    public static func formatCardTime(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let todayMidnight = calendar.startOfDay(for: now)
        guard let yesterdayMidnight = calendar.date(byAdding: .day, value: -1, to: todayMidnight) else { return "" }
        let itemDate = calendar.startOfDay(for: date)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeStr = timeFormatter.string(from: date)
        
        if itemDate == todayMidnight {
            return timeStr
        }
        
        if itemDate == yesterdayMidnight {
            return "Yesterday"
        }
        
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: todayMidnight) else { return "" }
        if itemDate > sevenDaysAgo {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            return dayFormatter.string(from: date)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"
        return dateFormatter.string(from: date)
    }
    
    /// Formats a date for the editor header: "4 Jun 2026 at 3:45 PM".
    public static func formatEditorHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}
