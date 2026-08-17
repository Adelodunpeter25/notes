import Foundation

public final class AppFlowyConverter {
    
    /// Converts an AppFlowy editor JSON document string into NoteKit blocks.
    public static func toBlocks(jsonString: String) -> [Block] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let document = json["document"] as? [String: Any],
              let children = document["children"] as? [[String: Any]] else {
            
            // Fallback: If raw text, represent as a single block
            if trimmed.isEmpty {
                return [Block(type: .text, content: "")]
            }
            return [Block(type: .text, content: jsonString)]
        }
        
        var blocks: [Block] = []
        for child in children {
            let typeStr = child["type"] as? String ?? "paragraph"
            
            // Extract plain text string from delta array in data, attributes, or root
            var text = ""
            let delta = (child["data"] as? [String: Any])?["delta"] as? [[String: Any]] ??
                        (child["delta"] as? [[String: Any]]) ??
                        (child["attributes"] as? [String: Any])?["delta"] as? [[String: Any]]
            
            if let deltaList = delta {
                for op in deltaList {
                    if let insert = op["insert"] as? String {
                        text += insert
                    }
                }
            }
            text = text.trimmingCharacters(in: .newlines)
            
            let blockType: BlockType
            var isChecked: Bool? = nil
            let attributes = (child["attributes"] as? [String: Any]) ?? (child["data"] as? [String: Any])
            
            switch typeStr {
            case "heading":
                let level = attributes?["level"] as? Int ?? 1
                if level == 1 {
                    blockType = .title
                } else if level == 2 {
                    blockType = .heading
                } else {
                    blockType = .subheading
                }
            case "todo_list":
                blockType = .todo
                isChecked = attributes?["checked"] as? Bool ?? false
            case "bullet_list":
                blockType = .bulletList
            case "numbered_list":
                blockType = .numberedList
            default:
                blockType = .text
            }
            
            blocks.append(Block(type: blockType, content: text, isChecked: isChecked))
        }
        
        if blocks.isEmpty {
            blocks.append(Block(type: .text, content: ""))
        }
        return blocks
    }
    
    /// Converts NoteKit blocks back into an AppFlowy editor JSON document string.
    public static func toAppFlowyJSON(blocks: [Block]) -> String {
        var children: [[String: Any]] = []
        
        for block in blocks {
            var child: [String: Any] = [:]
            let typeStr: String
            var attributes: [String: Any] = [:]
            
            switch block.type {
            case .title:
                typeStr = "heading"
                attributes["level"] = 1
            case .heading:
                typeStr = "heading"
                attributes["level"] = 2
            case .subheading:
                typeStr = "heading"
                attributes["level"] = 3
            case .todo:
                typeStr = "todo_list"
                attributes["checked"] = block.isChecked ?? false
            case .bulletList:
                typeStr = "bullet_list"
            case .dashedList:
                typeStr = "bullet_list"
            case .numberedList:
                typeStr = "numbered_list"
            case .text:
                typeStr = "paragraph"
            }
            
            child["type"] = typeStr
            
            // Build the delta operations structure
            let delta: [[String: Any]] = [
                ["insert": block.content]
            ]
            child["data"] = ["delta": delta]
            
            if !attributes.isEmpty {
                child["attributes"] = attributes
            }
            
            children.append(child)
        }
        
        let document: [String: Any] = [
            "type": "page",
            "children": children
        ]
        
        let root: [String: Any] = [
            "document": document
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: root, options: []),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }
        
        return "{}"
    }
}
