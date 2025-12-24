import XCTest
@testable import RemarkableWorkflowySync

final class ModelTests: XCTestCase {
    
    func testRemarkableDocumentInitialization() {
        let document = RemarkableDocument(
            id: "test-id",
            name: "Test Document",
            type: "pdf",
            lastModified: Date(),
            size: 1024,
            parentId: nil
        )
        
        XCTAssertEqual(document.id, "test-id")
        XCTAssertEqual(document.name, "Test Document")
        XCTAssertEqual(document.type, "pdf")
        XCTAssertTrue(document.isPDF)
        XCTAssertEqual(document.size, 1024)
        XCTAssertNil(document.parentId)
        XCTAssertFalse(document.isSelected)
    }
    
    func testRemarkableDocumentPDFDetection() {
        let pdfDoc = RemarkableDocument(
            id: "1", name: "test.pdf", type: "pdf", 
            lastModified: Date(), size: 100, parentId: nil
        )
        XCTAssertTrue(pdfDoc.isPDF)
        
        let notebookDoc = RemarkableDocument(
            id: "2", name: "notes", type: "notebook", 
            lastModified: Date(), size: 100, parentId: nil
        )
        XCTAssertFalse(notebookDoc.isPDF)
        
        let pdfNameDoc = RemarkableDocument(
            id: "3", name: "document.PDF", type: "unknown", 
            lastModified: Date(), size: 100, parentId: nil
        )
        XCTAssertTrue(pdfNameDoc.isPDF)
    }
    
    func testWorkflowyNodeInitialization() {
        let node = WorkflowyNode(
            id: "node-1",
            name: "Test Node",
            note: "This is a test note",
            parentId: "parent-1"
        )
        
        XCTAssertEqual(node.id, "node-1")
        XCTAssertEqual(node.name, "Test Node")
        XCTAssertEqual(node.note, "This is a test note")
        XCTAssertEqual(node.parentId, "parent-1")
        XCTAssertNil(node.children)
    }
    
    func testSyncPairDirections() {
        let directions = SyncPair.SyncDirection.allCases
        XCTAssertEqual(directions.count, 3)
        
        XCTAssertEqual(SyncPair.SyncDirection.remarkableToWorkflowy.displayName, "Remarkable → Workflowy")
        XCTAssertEqual(SyncPair.SyncDirection.workflowyToRemarkable.displayName, "Workflowy → Remarkable")
        XCTAssertEqual(SyncPair.SyncDirection.bidirectional.displayName, "Bidirectional")
    }
    
    func testAppSettingsDefaultValues() {
        let settings = AppSettings()
        
        XCTAssertTrue(settings.remarkableDeviceToken.isEmpty)
        XCTAssertTrue(settings.workflowyApiKey.isEmpty)
        XCTAssertTrue(settings.dropboxAccessToken.isEmpty)
        XCTAssertEqual(settings.syncInterval, 3600) // 1 hour
        XCTAssertTrue(settings.enableBackgroundSync)
        XCTAssertTrue(settings.autoConvertToPDF)
    }
    
    func testSyncStatusEquality() {
        XCTAssertEqual(SyncStatus.idle, SyncStatus.idle)
        XCTAssertEqual(SyncStatus.syncing, SyncStatus.syncing)
        XCTAssertEqual(SyncStatus.completed, SyncStatus.completed)
        XCTAssertEqual(SyncStatus.error("test"), SyncStatus.error("test"))
        
        XCTAssertNotEqual(SyncStatus.idle, SyncStatus.syncing)
        XCTAssertNotEqual(SyncStatus.error("test1"), SyncStatus.error("test2"))
    }
    
    func testSyncStatusDisplayProperties() {
        XCTAssertEqual(SyncStatus.idle.displayText, "Ready")
        XCTAssertEqual(SyncStatus.syncing.displayText, "Syncing...")
        XCTAssertEqual(SyncStatus.completed.displayText, "Completed")
        XCTAssertEqual(SyncStatus.error("Network error").displayText, "Error: Network error")
        
        // Test colors are properly assigned (basic check)
        XCTAssertNotNil(SyncStatus.idle.color)
        XCTAssertNotNil(SyncStatus.syncing.color)
        XCTAssertNotNil(SyncStatus.completed.color)
        XCTAssertNotNil(SyncStatus.error("test").color)
    }
}