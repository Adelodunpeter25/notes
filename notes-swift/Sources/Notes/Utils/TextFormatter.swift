import Foundation
#if os(macOS)
import AppKit
#endif

struct TextFormatter {
    /// Extracts plain text from either RTF-encoded or HTML-encoded content.
    static func extractPlainText(from content: String) -> String {
        // If it's our custom base64 RTF format, decode it first.
        #if os(macOS)
        if content.hasPrefix("rtf:"),
           let data = Data(base64Encoded: String(content.dropFirst(4))) {
            if let attr = NSAttributedString(rtf: data, documentAttributes: nil) {
                return attr.string
            } else if let attr = NSAttributedString(rtfd: data, documentAttributes: nil) {
                return attr.string
            }
            return "" // If decoding failed, don't show the raw base64 string
        }
        #endif
        
        // Otherwise, strip HTML tags and entities
        return stripHTML(from: content)
    }

    /// Strips HTML tags from a string and replaces common entities.
    static func stripHTML(from html: String) -> String {
        // Handle line breaks specifically to preserve them before stripping all tags
        let withNewlines = html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "</p>", with: "\n", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "</div>", with: "\n", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "</li>", with: "\n", options: .regularExpression, range: nil)
        
        // Basic regex to remove HTML tags
        let pattern = "<[^>]+>"
        let clean = withNewlines.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        
        // Handle basic entities
        return clean
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Derives a title from content (first non-empty line)
    static func deriveTitle(from content: String) -> String {
        let plainText = extractPlainText(from: content)
        let lines = plainText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard let firstLine = lines.first else { return "Untitled" }
        
        if firstLine.count > 100 {
            return String(firstLine.prefix(100)) + "..."
        }
        return firstLine
    }
}
