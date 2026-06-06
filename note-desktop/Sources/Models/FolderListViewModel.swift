import AppKit

public final class SidebarNode: NSObject {
    public let type: NodeType
    public var name: String
    public var folder: DBFolder?
    
    public enum NodeType {
        case allNotes
        case folder
        case divider
        case trash
    }
    
    public init(type: NodeType, name: String, folder: DBFolder? = nil) {
        self.type = type
        self.name = name
        self.folder = folder
    }
}

public final class FolderListViewModel {
    private let storage: StorageService
    private let userId: String
    
    public private(set) var data: [SidebarNode] = []
    
    public init(storage: StorageService, userId: String) {
        self.storage = storage
        self.userId = userId
    }
    
    public func reloadData() {
        let activeFolders = storage.listActiveFolders(userId: userId)
        
        var nodes: [SidebarNode] = []
        nodes.append(SidebarNode(type: .allNotes, name: "All Notes"))
        
        for folder in activeFolders {
            nodes.append(SidebarNode(type: .folder, name: folder.name, folder: folder))
        }
        
        nodes.append(SidebarNode(type: .divider, name: ""))
        nodes.append(SidebarNode(type: .trash, name: "Trash"))
        
        self.data = nodes
    }
    
    public func getCount(for node: SidebarNode) -> Int {
        switch node.type {
        case .allNotes:
            return storage.listActiveNotes(userId: userId).count
        case .folder:
            guard let folder = node.folder else { return 0 }
            return storage.listNotesInFolder(userId: userId, folderId: folder.id).count
        case .trash:
            return storage.listTrashNotes(userId: userId).count
        default:
            return 0
        }
    }
}
