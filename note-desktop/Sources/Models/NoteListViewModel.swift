import Foundation

public enum RowItem {
    case header(String)
    case note(DBNote)
}

public final class NoteListViewModel {
    private let noteService: NoteService
    private let storage: StorageService
    private let userId: String
    
    private var allNotes: [DBNote] = []
    private var filteredNotes: [DBNote] = []
    public private(set) var rowItems: [RowItem] = []
    
    public init(noteService: NoteService, storage: StorageService, userId: String) {
        self.noteService = noteService
        self.storage = storage
        self.userId = userId
    }
    
    public func updateNotes(_ notes: [DBNote], searchquery: String? = nil) {
        self.allNotes = notes
        filterNotes(query: searchquery)
    }
    
    public func filterNotes(query: String?) {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            filteredNotes = allNotes
        } else {
            filteredNotes = noteService.searchNotes(query: trimmed, userId: userId)
        }
        updateRowItems()
    }
    
    private func updateRowItems() {
        var newItems: [RowItem] = []
        
        let pinned = filteredNotes.filter { $0.isPinned }
        let unpinned = filteredNotes.filter { !$0.isPinned }
        
        if !pinned.isEmpty {
            newItems.append(.header("Pinned"))
            for note in pinned {
                newItems.append(.note(note))
            }
        }
        
        var currentSection: String? = nil
        for note in unpinned {
            let section = TimeUtils.getNoteSection(for: note.updatedAt)
            if section != currentSection {
                currentSection = section
                newItems.append(.header(section))
            }
            newItems.append(.note(note))
        }
        
        self.rowItems = newItems
    }
}
