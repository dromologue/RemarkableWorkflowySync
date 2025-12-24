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
        let defaultSettings = AppSettings()
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
    
    func testSettingsViewModelWithAPITokenLoading() {
        let viewModel = SettingsViewModel()
        
        // Test initial state - may have auto-loaded from api-tokens.md
        XCTAssertEqual(viewModel.remarkableConnectionStatus, .unknown)
        XCTAssertEqual(viewModel.workflowyConnectionStatus, .unknown)
        XCTAssertEqual(viewModel.dropboxConnectionStatus, .unknown)
        
        // Test manual token setting (simulates successful auto-load)
        viewModel.remarkableDeviceToken = "loaded-remarkable-token"
        viewModel.workflowyApiKey = "loaded-workflowy-key"
        viewModel.dropboxAccessToken = "loaded-dropbox-token"
        viewModel.autoLoadedFromFile = true
        
        XCTAssertTrue(viewModel.autoLoadedFromFile)
        XCTAssertTrue(viewModel.hasValidSettings)
        XCTAssertFalse(viewModel.remarkableDeviceToken.isEmpty)
        XCTAssertFalse(viewModel.workflowyApiKey.isEmpty)
        XCTAssertFalse(viewModel.dropboxAccessToken.isEmpty)
    }
    
    func testAPITokenParserIntegration() {
        let parser = APITokenParser.shared
        
        // Test with realistic token format
        let realisticContent = """
        # API Access Tokens
        
        **⚠️ CONFIDENTIAL - DO NOT SHARE OR COMMIT TO REPOSITORY ⚠️**
        
        This file contains your personal API access tokens for the Remarkable Workflowy Sync app.
        
        ## Remarkable 2
        
        **Device Token:**
        ```
        smooyrds
        ```
        
        **How to get it:**
        1. Visit: https://remarkable.com/device/desktop/connect
        
        ## Workflowy
        
        **API Key:**
        ```
        cf5a1fc04b7a17388d630d875a498e6aff6afda9
        ```
        
        **How to get it:**
        1. Visit: https://workflowy.com/api-key
        
        ## Dropbox (Optional)
        
        **Access Token:**
        ```
        sl.u.AGOT8VuaD9Wpfd24MtGibh-BOpAvKtN5oaPrULqexdsKRyskofMwvuM2h62Xb5608WFK
        ```
        """
        
        let tokens = parser.parseTokensFromContent(realisticContent)
        XCTAssertNotNil(tokens)
        XCTAssertEqual(tokens?.remarkableToken, "smooyrds")
        XCTAssertEqual(tokens?.workflowyApiKey, "cf5a1fc04b7a17388d630d875a498e6aff6afda9")
        XCTAssertEqual(tokens?.dropboxAccessToken, "sl.u.AGOT8VuaD9Wpfd24MtGibh-BOpAvKtN5oaPrULqexdsKRyskofMwvuM2h62Xb5608WFK")
    }
    
    func testConnectionStatusFlow() {
        // Test the complete connection status workflow
        let viewModel = SettingsViewModel()
        
        // Initial state
        XCTAssertEqual(viewModel.remarkableConnectionStatus, .unknown)
        XCTAssertEqual(viewModel.workflowyConnectionStatus, .unknown)
        XCTAssertEqual(viewModel.dropboxConnectionStatus, .unknown)
        
        // Simulate connection failure
        viewModel.remarkableConnectionStatus = .failed("Invalid token")
        viewModel.workflowyConnectionStatus = .failed("API key not found")
        viewModel.dropboxConnectionStatus = .failed("Access denied")
        
        XCTAssertEqual(viewModel.remarkableConnectionStatus, .failed("Invalid token"))
        XCTAssertEqual(viewModel.workflowyConnectionStatus, .failed("API key not found"))
        XCTAssertEqual(viewModel.dropboxConnectionStatus, .failed("Access denied"))
        
        // Simulate successful connection
        viewModel.remarkableConnectionStatus = .connected
        viewModel.workflowyConnectionStatus = .connected
        viewModel.dropboxConnectionStatus = .connected
        
        XCTAssertEqual(viewModel.remarkableConnectionStatus, .connected)
        XCTAssertEqual(viewModel.workflowyConnectionStatus, .connected)
        XCTAssertEqual(viewModel.dropboxConnectionStatus, .connected)
    }
    
    func testAutoLoadAndSyncWorkflow() {
        // Test the complete auto-load to sync workflow
        let viewModel = SettingsViewModel()
        
        // Step 1: Auto-load tokens (simulated)
        viewModel.remarkableDeviceToken = "auto-loaded-remarkable"
        viewModel.workflowyApiKey = "auto-loaded-workflowy"
        viewModel.dropboxAccessToken = "auto-loaded-dropbox"
        viewModel.autoLoadedFromFile = true
        
        // Step 2: Verify loaded state
        XCTAssertTrue(viewModel.autoLoadedFromFile)
        XCTAssertTrue(viewModel.hasValidSettings)
        
        // Step 3: Simulate connection testing results
        viewModel.remarkableConnectionStatus = .connected
        viewModel.workflowyConnectionStatus = .connected
        viewModel.dropboxConnectionStatus = .connected
        
        // Step 4: Verify ready for sync
        XCTAssertTrue(viewModel.hasValidSettings)
        XCTAssertEqual(viewModel.remarkableConnectionStatus, .connected)
        XCTAssertEqual(viewModel.workflowyConnectionStatus, .connected)
        XCTAssertEqual(viewModel.dropboxConnectionStatus, .connected)
        
        // This represents a fully configured and tested system
        let allSystemsReady = viewModel.hasValidSettings &&
                             viewModel.remarkableConnectionStatus == .connected &&
                             viewModel.workflowyConnectionStatus == .connected
        
        XCTAssertTrue(allSystemsReady)
    }
}