import XCTest
@testable import RemarkableWorkflowySync

@MainActor
final class ViewModelTests: XCTestCase {
    
    func testMainViewModelInitialization() async {
        let viewModel = MainViewModel()
        
        XCTAssertTrue(viewModel.documents.isEmpty)
        XCTAssertTrue(viewModel.selectedDocuments.isEmpty)
        XCTAssertEqual(viewModel.syncStatus, .idle)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.allDocumentsSelected)
    }
    
    func testMainViewModelDocumentSelection() {
        let viewModel = MainViewModel()
        
        // Add mock documents
        let doc1 = RemarkableDocument(id: "1", name: "Doc1", type: "pdf", lastModified: Date(), size: 100, parentId: nil)
        let doc2 = RemarkableDocument(id: "2", name: "Doc2", type: "notebook", lastModified: Date(), size: 200, parentId: nil)
        viewModel.documents = [doc1, doc2]
        
        // Test select all
        viewModel.toggleSelectAll()
        XCTAssertEqual(viewModel.selectedDocuments.count, 2)
        XCTAssertTrue(viewModel.allDocumentsSelected)
        
        // Test deselect all
        viewModel.toggleSelectAll()
        XCTAssertTrue(viewModel.selectedDocuments.isEmpty)
        XCTAssertFalse(viewModel.allDocumentsSelected)
    }
    
    func testSettingsViewModelInitialization() {
        let viewModel = SettingsViewModel()
        
        XCTAssertTrue(viewModel.remarkableDeviceToken.isEmpty)
        XCTAssertTrue(viewModel.workflowyApiKey.isEmpty)
        XCTAssertTrue(viewModel.dropboxAccessToken.isEmpty)
        XCTAssertEqual(viewModel.syncInterval, 3600)
        XCTAssertTrue(viewModel.enableBackgroundSync)
        XCTAssertTrue(viewModel.autoConvertToPDF)
        XCTAssertEqual(viewModel.remarkableConnectionStatus, .unknown)
        XCTAssertEqual(viewModel.workflowyConnectionStatus, .unknown)
        XCTAssertFalse(viewModel.isTestingConnection)
        XCTAssertFalse(viewModel.hasValidSettings)
    }
    
    func testSettingsViewModelValidation() {
        let viewModel = SettingsViewModel()
        
        // Initially invalid
        XCTAssertFalse(viewModel.hasValidSettings)
        
        // Set partial settings
        viewModel.remarkableDeviceToken = "token"
        XCTAssertFalse(viewModel.hasValidSettings)
        
        viewModel.workflowyApiKey = "api-key"
        XCTAssertFalse(viewModel.hasValidSettings)
        
        // Set all required settings
        viewModel.dropboxAccessToken = "access-token"
        XCTAssertTrue(viewModel.hasValidSettings)
        
        // Clear one setting
        viewModel.workflowyApiKey = ""
        XCTAssertFalse(viewModel.hasValidSettings)
    }
    
    func testConnectionStatusTypes() {
        let unknown = ConnectionStatus.unknown
        let connected = ConnectionStatus.connected
        let failed = ConnectionStatus.failed("Test error")
        
        XCTAssertEqual(unknown.displayText, "Unknown")
        XCTAssertEqual(connected.displayText, "Connected")
        XCTAssertEqual(failed.displayText, "Failed: Test error")
        
        // Test colors are assigned
        XCTAssertNotNil(unknown.color)
        XCTAssertNotNil(connected.color)
        XCTAssertNotNil(failed.color)
    }
    
    func testMenuBarManagerInitialization() async {
        let manager = MenuBarManager()
        XCTAssertNotNil(manager)
        
        // Wait a moment for async initialization
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
}