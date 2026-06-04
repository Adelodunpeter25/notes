import XCTest
@testable import NoteKit

final class TodoAttachmentTests: XCTestCase {
    
    func testTodoAttachmentStateAndToggle() {
        let blockId = UUID()
        var toggledState: Bool?
        
        let attachment = TodoAttachment(blockId: blockId, isChecked: false) { newState in
            toggledState = newState
        }
        
        XCTAssertEqual(attachment.blockId, blockId)
        XCTAssertFalse(attachment.isChecked)
        
        // Simulate checking the todo
        attachment.isChecked = true
        attachment.onToggle?(true)
        
        XCTAssertEqual(toggledState, true)
    }
}
