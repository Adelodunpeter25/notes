import Foundation

public final class NoteUtils {
    
    /// Parses JSON editor contents or raw text into plain text lines.
    public static func extractLines(from content: String) -> [String] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        
        guard let data = trimmed.data(using: .utf8) else {
            return content.components(separatedBy: .newlines)
        }
        
        do {
            if let decoded = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                var lines: [String] = []
                let rootNode = (decoded["document"] as? [String: Any]) ?? decoded
                collectLines(from: rootNode, into: &lines)
                return lines
            }
        } catch {
            // Fallback for raw text
        }
        
        return content.components(separatedBy: .newlines)
    }
    
    private static func collectLines(from node: [String: Any], into out: inout [String]) {
        // Extract from delta formatting lists
        let delta = node["delta"] as? [[String: Any]] ??
                    (node["data"] as? [String: Any])?["delta"] as? [[String: Any]] ??
                    (node["attributes"] as? [String: Any])?["delta"] as? [[String: Any]]
        
        if let deltaList = delta {
            var blockText = ""
            for op in deltaList {
                if let insert = op["insert"] as? String {
                    blockText += insert
                }
            }
            
            for line in blockText.components(separatedBy: .newlines) {
                out.append(line)
            }
        }
        
        if let children = node["children"] as? [[String: Any]] {
            for child in children {
                collectLines(from: child, into: &out)
            }
        }
    }
    
    /// Derives the note title from the first non-empty line of content.
    public static func titleFromContent(_ content: String, maxLength: Int = 80) -> String {
        for line in extractLines(from: content) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            if trimmedLine.count <= maxLength {
                return trimmedLine
            }
            let index = trimmedLine.index(trimmedLine.startIndex, offsetBy: maxLength)
            return String(trimmedLine[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return "Untitled"
    }
    
    /// Determines if a note has no user-generated title and no content, making it eligible for auto-deletion.
    public static func isNoteEmpty(title: String, content: String) -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle != "Untitled" && !cleanTitle.isEmpty {
            return false
        }
        
        let lines = extractLines(from: content)
        let totalText = lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return totalText.isEmpty
    }
}
