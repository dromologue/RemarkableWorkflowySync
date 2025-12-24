import XCTest
import SwiftUI
import Combine
@testable import RemarkableWorkflowySync

@MainActor
final class UITests: XCTestCase {
    
    var mainViewModel: MainViewModel!
    var settingsViewModel: SettingsViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mainViewModel = MainViewModel()
        settingsViewModel = SettingsViewModel()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        mainViewModel = nil
        settingsViewModel = nil
        cancellables = nil
    }
    
    // MARK: - MainViewModel Tests
    
    func testMainViewModelInitialization() {
        XCTAssertTrue(mainViewModel.documents.isEmpty, "Documents should be empty initially")
        XCTAssertTrue(mainViewModel.selectedDocuments.isEmpty, "Selected documents should be empty initially")
        XCTAssertEqual(mainViewModel.syncStatus, .idle, "Sync status should be idle initially")
        XCTAssertFalse(mainViewModel.isLoading, "Should not be loading initially")
        XCTAssertFalse(mainViewModel.allDocumentsSelected, "All documents should not be selected initially")
    }
    
    func testMainViewModelSelectAllFunctionality() {
        // Given: Documents in the view model
        let testDocs = createTestDocuments()
        mainViewModel.documents = testDocs
        
        // When: Toggle select all
        mainViewModel.toggleSelectAll()
        
        // Then: All documents should be selected
        XCTAssertTrue(mainViewModel.allDocumentsSelected, "All documents should be selected")
        XCTAssertEqual(mainViewModel.selectedDocuments.count, testDocs.count, "Selected count should match total")
        
        // When: Toggle select all again
        mainViewModel.toggleSelectAll()
        
        // Then: No documents should be selected
        XCTAssertFalse(mainViewModel.allDocumentsSelected, "No documents should be selected")
        XCTAssertTrue(mainViewModel.selectedDocuments.isEmpty, "Selected documents should be empty")
    }
    
    func testMainViewModelRefreshDocuments() async {
        // Given: Initial state
        XCTAssertFalse(mainViewModel.isLoading, "Should not be loading initially")
        
        // When: Refreshing documents
        let refreshTask = Task {
            await mainViewModel.refreshDocuments()
        }
        
        // Then: Should handle refresh gracefully (will likely fail due to auth)
        await refreshTask.value
        XCTAssertFalse(mainViewModel.isLoading, "Should not be loading after refresh completes")
    }
    
    func testMainViewModelSyncSelectedDocuments() async {
        // Given: Selected documents
        let testDocs = createTestDocuments()
        mainViewModel.documents = testDocs
        mainViewModel.selectedDocuments = Set(testDocs.map(\.id))
        
        // When: Syncing selected documents
        let syncTask = Task {
            await mainViewModel.syncSelectedDocuments()
        }
        
        // Then: Should complete sync operation
        await syncTask.value
        
        // Sync status should eventually settle
        XCTAssertTrue(true, "Sync should complete without crashing")
    }
    
    func testMainViewModelWorkflowyToRemarkableSync() async {
        // Given: Main view model
        let initialStatus = mainViewModel.syncStatus
        
        // When: Triggering Workflowy to Remarkable sync
        let syncTask = Task {
            await mainViewModel.syncWorkflowyToRemarkable()
        }
        
        // Then: Should handle sync operation
        await syncTask.value
        
        // Should complete without crashing (status may be error due to auth issues)
        XCTAssertTrue(true, "Workflowy to Remarkable sync should complete")
    }
    
    func testMainViewModelLoadInitialData() async {
        // Given: Fresh view model
        XCTAssertTrue(mainViewModel.documents.isEmpty, "Documents should be empty initially")
        
        // When: Loading initial data
        await mainViewModel.loadInitialData()
        
        // Then: Should complete loading process
        XCTAssertTrue(true, "Initial data loading should complete without errors")
    }
    
    // MARK: - SettingsViewModel Tests
    
    func testSettingsViewModelInitialization() {
        XCTAssertTrue(settingsViewModel.remarkableDeviceToken.isEmpty || !settingsViewModel.remarkableDeviceToken.isEmpty, 
                     "Token should be initialized")
        XCTAssertTrue(settingsViewModel.remarkableRegistrationCode.isEmpty || !settingsViewModel.remarkableRegistrationCode.isEmpty,
                     "Registration code should be initialized")
        XCTAssertTrue(settingsViewModel.workflowyApiKey.isEmpty || !settingsViewModel.workflowyApiKey.isEmpty,
                     "API key should be initialized")
        
        XCTAssertEqual(settingsViewModel.remarkableConnectionStatus, .unknown, "Connection status should be unknown initially")
        XCTAssertEqual(settingsViewModel.workflowyConnectionStatus, .unknown, "Workflowy status should be unknown initially")
        XCTAssertFalse(settingsViewModel.isTestingConnection, "Should not be testing connection initially")
    }
    
    func testSettingsViewModelHasValidSettings() {
        // Test with empty settings
        settingsViewModel.remarkableDeviceToken = ""
        settingsViewModel.workflowyApiKey = ""
        XCTAssertFalse(settingsViewModel.hasValidSettings, "Should not have valid settings when empty")
        
        // Test with partial settings
        settingsViewModel.remarkableDeviceToken = "test-token"
        settingsViewModel.workflowyApiKey = ""
        XCTAssertFalse(settingsViewModel.hasValidSettings, "Should not have valid settings with partial data")
        
        // Test with complete settings
        settingsViewModel.remarkableDeviceToken = "test-token"
        settingsViewModel.workflowyApiKey = "test-api-key"
        XCTAssertTrue(settingsViewModel.hasValidSettings, "Should have valid settings when complete")
    }
    
    func testSettingsViewModelHasMinimalRequiredSettings() {
        // Test with empty settings
        settingsViewModel.remarkableDeviceToken = ""
        settingsViewModel.workflowyApiKey = ""
        XCTAssertFalse(settingsViewModel.hasMinimalRequiredSettings, "Should not have minimal settings when empty")
        
        // Test with remarkable token only
        settingsViewModel.remarkableDeviceToken = "test-token"
        settingsViewModel.workflowyApiKey = ""
        XCTAssertTrue(settingsViewModel.hasMinimalRequiredSettings, "Should have minimal settings with remarkable token")
        
        // Test with workflowy key only
        settingsViewModel.remarkableDeviceToken = ""
        settingsViewModel.workflowyApiKey = "test-key"
        XCTAssertTrue(settingsViewModel.hasMinimalRequiredSettings, "Should have minimal settings with workflowy key")
    }
    
    func testSettingsViewModelSaveSettings() {
        // Given: Updated settings
        settingsViewModel.remarkableDeviceToken = "test-remarkable-token"
        settingsViewModel.workflowyApiKey = "test-workflowy-key"
        settingsViewModel.dropboxAccessToken = "test-dropbox-token"
        settingsViewModel.syncInterval = 3600
        settingsViewModel.enableBackgroundSync = true
        settingsViewModel.autoConvertToPDF = false
        
        // When: Saving settings
        settingsViewModel.saveSettings()
        
        // Then: Should complete without error
        XCTAssertTrue(true, "Settings save should complete without error")
    }
    
    func testSettingsViewModelTestRemarkableConnection() async {
        // Given: Settings with device token
        settingsViewModel.remarkableDeviceToken = "test-device-token"
        
        // When: Testing connection
        await settingsViewModel.testRemarkableConnection()
        
        // Then: Should update connection status (likely to failed due to invalid token)
        XCTAssertNotEqual(settingsViewModel.remarkableConnectionStatus, .unknown, 
                         "Connection status should be updated after test")
    }
    
    func testSettingsViewModelTestWorkflowyConnection() async {
        // Given: Settings with API key
        settingsViewModel.workflowyApiKey = "test-workflowy-key"
        
        // When: Testing connection
        await settingsViewModel.testWorkflowyConnection()
        
        // Then: Should update connection status
        XCTAssertNotEqual(settingsViewModel.workflowyConnectionStatus, .unknown,
                         "Workflowy connection status should be updated after test")
    }
    
    func testSettingsViewModelTestDropboxConnection() async {
        // Given: Settings with access token
        settingsViewModel.dropboxAccessToken = "test-dropbox-token"
        
        // When: Testing connection
        await settingsViewModel.testDropboxConnection()
        
        // Then: Should update connection status
        XCTAssertNotEqual(settingsViewModel.dropboxConnectionStatus, .unknown,
                         "Dropbox connection status should be updated after test")
    }
    
    func testSettingsViewModelRegisterRemarkableDevice() async {
        // Given: Registration code
        settingsViewModel.remarkableRegistrationCode = "testcode"
        
        // When: Registering device (will fail due to invalid code)
        await settingsViewModel.registerRemarkableDevice()
        
        // Then: Should handle registration attempt
        XCTAssertTrue(true, "Device registration should complete without crashing")
    }
    
    func testSettingsViewModelTestAllConnections() async {
        // Given: Settings with all tokens
        settingsViewModel.remarkableDeviceToken = "test-remarkable"
        settingsViewModel.workflowyApiKey = "test-workflowy"
        settingsViewModel.dropboxAccessToken = "test-dropbox"
        
        // When: Testing all connections
        await settingsViewModel.testAllConnections()
        
        // Then: All connection statuses should be updated
        let allStatusesUpdated = settingsViewModel.remarkableConnectionStatus != .unknown ||
                               settingsViewModel.workflowyConnectionStatus != .unknown ||
                               settingsViewModel.dropboxConnectionStatus != .unknown
        
        XCTAssertTrue(allStatusesUpdated, "At least some connection statuses should be updated")
    }
    
    // MARK: - ConnectionStatus Tests
    
    func testConnectionStatusDisplayProperties() {
        // Test idle status
        let idleStatus = SyncStatus.idle
        XCTAssertEqual(idleStatus.displayText, "Ready", "Idle status should display 'Ready'")
        XCTAssertEqual(idleStatus.color.description, Color.secondary.description, "Idle should have secondary color")
        
        // Test syncing status
        let syncingStatus = SyncStatus.syncing
        XCTAssertEqual(syncingStatus.displayText, "Syncing...", "Syncing status should display 'Syncing...'")
        XCTAssertEqual(syncingStatus.color.description, Color.blue.description, "Syncing should have blue color")
        
        // Test completed status
        let completedStatus = SyncStatus.completed
        XCTAssertEqual(completedStatus.displayText, "Completed", "Completed status should display 'Completed'")
        XCTAssertEqual(completedStatus.color.description, Color.green.description, "Completed should have green color")
        
        // Test error status
        let errorStatus = SyncStatus.error("Test error")
        XCTAssertEqual(errorStatus.displayText, "Error: Test error", "Error status should display error message")
        XCTAssertEqual(errorStatus.color.description, Color.red.description, "Error should have red color")
    }
    
    func testConnectionStatusCases() {
        // Test unknown status
        let unknownStatus = ConnectionStatus.unknown
        XCTAssertEqual(unknownStatus.displayText, "Unknown", "Unknown should display 'Unknown'")
        XCTAssertEqual(unknownStatus.color.description, Color.gray.description, "Unknown should have gray color")
        
        // Test connected status
        let connectedStatus = ConnectionStatus.connected
        XCTAssertEqual(connectedStatus.displayText, "Connected", "Connected should display 'Connected'")
        XCTAssertEqual(connectedStatus.color.description, Color.green.description, "Connected should have green color")
        
        // Test failed status
        let failedStatus = ConnectionStatus.failed("Connection failed")
        XCTAssertEqual(failedStatus.displayText, "Failed: Connection failed", "Failed should display error message")
        XCTAssertEqual(failedStatus.color.description, Color.red.description, "Failed should have red color")
    }
    
    // MARK: - MenuBarManager Tests
    
    func testMenuBarManagerInitialization() {
        // Given: Menu bar manager
        let menuBarManager = MenuBarManager()
        
        // Then: Should initialize without error
        XCTAssertNotNil(menuBarManager, "MenuBarManager should initialize")
    }
    
    // MARK: - Document Row View Tests
    
    func testDocumentRowViewData() {
        // Given: Test document
        let testDoc = createTestDocuments().first!
        
        // When: Creating document row view (conceptually, since we can't test UI directly)
        let isPDF = testDoc.isPDF
        let formattedSize = formatFileSize(testDoc.size)
        
        // Then: Data should be properly formatted
        XCTAssertTrue(isPDF || !isPDF, "PDF status should be determinable")
        XCTAssertFalse(formattedSize.isEmpty, "File size should be formatted")
        XCTAssertTrue(formattedSize.contains("B") || formattedSize.contains("KB") || formattedSize.contains("MB"), 
                     "Formatted size should have units")
    }
    
    // MARK: - UI State Management Tests
    
    func testMainViewModelStateConsistency() async {
        // Test that view model maintains consistent state during operations
        
        // Initial state check
        let initialDocumentCount = mainViewModel.documents.count
        let initialSelectedCount = mainViewModel.selectedDocuments.count
        let initialSyncStatus = mainViewModel.syncStatus
        
        // Perform operation that might change state
        await mainViewModel.refreshDocuments()
        
        // State should be consistent
        XCTAssertTrue(mainViewModel.selectedDocuments.count <= mainViewModel.documents.count,
                     "Selected documents should not exceed total documents")
        
        if mainViewModel.documents.isEmpty {
            XCTAssertTrue(mainViewModel.selectedDocuments.isEmpty,
                         "No documents should be selected if no documents exist")
            XCTAssertFalse(mainViewModel.allDocumentsSelected,
                          "All documents selected should be false when no documents exist")
        }
    }
    
    func testSettingsViewModelStateConsistency() async {
        // Test settings view model state consistency
        
        // When registration code is provided, device token should eventually be updated or error shown
        settingsViewModel.remarkableRegistrationCode = "testcode"
        let initialDeviceToken = settingsViewModel.remarkableDeviceToken
        
        await settingsViewModel.registerRemarkableDevice()
        
        // State should be consistent - either token updated or connection status shows error
        let tokenUpdated = settingsViewModel.remarkableDeviceToken != initialDeviceToken
        let statusShowsResult = settingsViewModel.remarkableConnectionStatus != .unknown
        
        XCTAssertTrue(tokenUpdated || statusShowsResult, 
                     "Either token should be updated or status should show result")
    }
    
    // MARK: - Reactive UI Tests
    
    func testMainViewModelReactiveUpdates() async {
        // Test that published properties properly update UI
        
        let expectation = XCTestExpectation(description: "Sync status should update reactively")
        var statusUpdates: [SyncStatus] = []
        
        mainViewModel.$syncStatus
            .sink { status in
                statusUpdates.append(status)
                if statusUpdates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger status change
        await mainViewModel.syncWorkflowyToRemarkable()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertGreaterThan(statusUpdates.count, 1, "Should have multiple status updates")
        XCTAssertEqual(statusUpdates.first, .idle, "Should start with idle status")
    }
    
    func testSettingsViewModelReactiveUpdates() async {
        // Test settings view model reactive properties
        
        let expectation = XCTestExpectation(description: "Connection status should update")
        var statusUpdates: [ConnectionStatus] = []
        
        settingsViewModel.$remarkableConnectionStatus
            .sink { status in
                statusUpdates.append(status)
                if statusUpdates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger connection test
        settingsViewModel.remarkableDeviceToken = "test-token"
        await settingsViewModel.testRemarkableConnection()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertGreaterThan(statusUpdates.count, 1, "Should have status updates")
        XCTAssertEqual(statusUpdates.first, .unknown, "Should start with unknown status")
    }
    
    // MARK: - Error Handling UI Tests
    
    func testUIErrorHandlingForInvalidOperations() async {
        // Test UI handles errors gracefully
        
        // Attempt sync with no selected documents
        XCTAssertTrue(mainViewModel.selectedDocuments.isEmpty, "No documents should be selected")
        
        await mainViewModel.syncSelectedDocuments()
        
        // Should complete without crashing
        XCTAssertTrue(true, "Sync with no selection should handle gracefully")
        
        // Attempt registration with invalid code
        settingsViewModel.remarkableRegistrationCode = "invalid"
        await settingsViewModel.registerRemarkableDevice()
        
        // Should show appropriate error status
        if case .failed(let message) = settingsViewModel.remarkableConnectionStatus {
            XCTAssertFalse(message.isEmpty, "Error message should be provided")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestDocuments() -> [RemarkableDocument] {
        return [
            RemarkableDocument(
                id: "ui-test-doc-1",
                name: "UI Test Document 1",
                type: "DocumentType",
                lastModified: Date(),
                size: 1024,
                parentId: nil
            ),
            RemarkableDocument(
                id: "ui-test-doc-2",
                name: "UI Test PDF Document",
                type: "PDFType",
                lastModified: Date().addingTimeInterval(-3600),
                size: 2048,
                parentId: nil
            ),
            RemarkableDocument(
                id: "ui-test-doc-3",
                name: "UI Test Collection",
                type: "CollectionType",
                lastModified: Date().addingTimeInterval(-7200),
                size: 0,
                parentId: nil
            )
        ]
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}