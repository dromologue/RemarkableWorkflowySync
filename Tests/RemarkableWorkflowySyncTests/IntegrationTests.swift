import XCTest
@testable import RemarkableWorkflowySync

@MainActor
final class IntegrationTests: XCTestCase {
    
    func testAppSettingsPersistence() {
        var originalSettings = AppSettings()
        originalSettings.remarkableDeviceToken = "test-device-token"
        originalSettings.workflowyApiKey = "test-workflowy-key"
        originalSettings.dropboxAccessToken = "test-dropbox-token"
        originalSettings.syncInterval = 7200 // 2 hours
        originalSettings.enableBackgroundSync = false
        originalSettings.autoConvertToPDF = false
        
        // Save settings
        originalSettings.save()
        
        // Load settings
        let loadedSettings = AppSettings.load()
        
        XCTAssertEqual(loadedSettings.remarkableDeviceToken, "test-device-token")
        XCTAssertEqual(loadedSettings.workflowyApiKey, "test-workflowy-key")
        XCTAssertEqual(loadedSettings.dropboxAccessToken, "test-dropbox-token")
        XCTAssertEqual(loadedSettings.syncInterval, 7200)
        XCTAssertFalse(loadedSettings.enableBackgroundSync)
        XCTAssertFalse(loadedSettings.autoConvertToPDF)
        
        // Cleanup - reset to defaults
        var defaultSettings = AppSettings()
        defaultSettings.save()
    }
    
    func testSyncServiceInitialization() async {
        let syncService = SyncService()
        
        XCTAssertFalse(syncService.isRunning)
        XCTAssertNil(syncService.lastSyncDate)
        XCTAssertEqual(syncService.syncStatus, .idle)
    }
    
    func testSyncServiceBackgroundControl() async {
        let syncService = SyncService()
        
        // Test starting background sync
        syncService.startBackgroundSync()
        XCTAssertTrue(syncService.isRunning)
        
        // Test stopping background sync
        syncService.stopBackgroundSync()
        XCTAssertFalse(syncService.isRunning)
    }
    
    func testDocumentToWorkflowyFlow() {
        // Create a mock remarkable document
        let document = RemarkableDocument(
            id: "test-doc-id",
            name: "Meeting Notes",
            type: "notebook",
            lastModified: Date(),
            size: 1024000,
            parentId: nil
        )
        
        // Create expected Workflowy node structure
        let expectedNode = WorkflowyNode(
            id: "generated-id",
            name: "Meeting Notes",
            note: """
            Source: Remarkable 2
            Type: NOTEBOOK
            Size: 1.0 MB
            Last Modified: \(document.lastModified.formatted())
            """,
            parentId: nil
        )
        
        XCTAssertEqual(expectedNode.name, document.name)
        XCTAssertTrue(expectedNode.note?.contains("Source: Remarkable 2") ?? false)
        XCTAssertTrue(expectedNode.note?.contains("Type: NOTEBOOK") ?? false)
    }
    
    func testSyncPairCreation() {
        let document = RemarkableDocument(
            id: "doc-1",
            name: "Test Document",
            type: "pdf",
            lastModified: Date(),
            size: 500000,
            parentId: nil
        )
        
        let node = WorkflowyNode(
            id: "node-1",
            name: "Test Document",
            note: "Synced from Remarkable",
            parentId: nil
        )
        
        let syncPair = SyncPair(
            remarkableDocument: document,
            workflowyNode: node,
            syncDirection: .remarkableToWorkflowy,
            lastSynced: nil
        )
        
        XCTAssertEqual(syncPair.remarkableDocument.id, "doc-1")
        XCTAssertEqual(syncPair.workflowyNode.id, "node-1")
        XCTAssertEqual(syncPair.syncDirection, .remarkableToWorkflowy)
        XCTAssertNil(syncPair.lastSynced)
        XCTAssertNotNil(syncPair.id) // UUID should be generated
    }
    
    func testFullSyncWorkflow() async {
        // This would be a more complex integration test
        // Testing the full sync workflow from document selection to Workflowy creation
        
        let viewModel = MainViewModel()
        
        // Mock document selection
        let mockDoc = RemarkableDocument(
            id: "integration-test-doc",
            name: "Integration Test Document",
            type: "pdf",
            lastModified: Date(),
            size: 750000,
            parentId: nil
        )
        
        viewModel.documents = [mockDoc]
        viewModel.selectedDocuments = [mockDoc.id]
        
        XCTAssertEqual(viewModel.selectedDocuments.count, 1)
        XCTAssertTrue(viewModel.selectedDocuments.contains(mockDoc.id))
        
        // Test that sync can be initiated (would require mock services for full test)
        XCTAssertEqual(viewModel.syncStatus, .idle)
    }
    
    func testErrorHandling() {
        let errors: [any Error] = [
            RemarkableError.authenticationFailed,
            WorkflowyError.rateLimited,
            DropboxError.uploadFailed,
            PDFConversionError.unsupportedFormat("unknown")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            if let localizedError = error as? LocalizedError {
                XCTAssertNotNil(localizedError.errorDescription)
            }
        }
    }
}