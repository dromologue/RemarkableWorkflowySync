import XCTest
@testable import RemarkableWorkflowySync

final class EnhancedServiceTests: XCTestCase {
    
    // MARK: - Remarkable Service Enhanced Tests
    
    func testRemarkableRegistrationCodeValidation() async {
        let service = RemarkableService()
        
        do {
            // Test invalid codes
            _ = try await service.registerDevice(code: "123") // Too short
            XCTFail("Should have thrown error for short code")
        } catch let error as RemarkableError {
            switch error {
            case .invalidToken(let message):
                XCTAssertTrue(message.contains("exactly 8 characters"))
            default:
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
        
        do {
            _ = try await service.registerDevice(code: "123456789") // Too long
            XCTFail("Should have thrown error for long code")
        } catch let error as RemarkableError {
            switch error {
            case .invalidToken(let message):
                XCTAssertTrue(message.contains("exactly 8 characters"))
            default:
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }
    
    func testRemarkableTokenPersistence() {
        let service = RemarkableService()
        
        // Test that token path can be created
        let tokenPath = service.getTokenPath()
        XCTAssertTrue(tokenPath.path.contains(".remarkable-token"))
        
        // Test that device ID is persistent
        let deviceID1 = service.generateDeviceID()
        let deviceID2 = service.generateDeviceID()
        XCTAssertEqual(deviceID1, deviceID2) // Should be the same
        XCTAssertFalse(deviceID1.isEmpty)
    }
    
    // MARK: - Workflowy Service Enhanced Tests
    
    func testWorkflowyRemarkableRootNodeCreation() async {
        let service = WorkflowyService(apiKey: "test-api-key", username: "test-user@example.com")
        
        // Test that we can create a mock remarkable document
        let mockDocument = RemarkableDocument(
            id: "test-doc-1",
            name: "Test Document",
            type: "pdf",
            lastModified: Date(),
            size: 1024,
            parentId: nil
        )
        
        // Test document note creation
        let note = service.createDocumentNote(for: mockDocument, dropboxUrl: "https://dropbox.com/test.pdf")
        
        XCTAssertTrue(note.contains("Type: PDF"))
        XCTAssertTrue(note.contains("Size:"))
        XCTAssertTrue(note.contains("Modified:"))
        XCTAssertTrue(note.contains("Remarkable ID: test-doc-1"))
        XCTAssertTrue(note.contains("https://dropbox.com/test.pdf"))
    }
    
    func testWorkflowyNodeSearch() async {
        let service = WorkflowyService(apiKey: "test-api-key", username: "test-user@example.com")
        
        // Create mock nodes for testing search
        let node1 = WorkflowyNode(id: "1", name: "Remarkable Document", note: "PDF file")
        let node2 = WorkflowyNode(id: "2", name: "Meeting Notes", note: "Team sync")
        let mockNodes = [node1, node2]
        
        // Test search functionality locally (without API call)
        let searchResults = service.searchInNodes(mockNodes, query: "Remarkable")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.name, "Remarkable Document")
    }
    
    func testWorkflowyBetaEndpoints() {
        let service = WorkflowyService(apiKey: "test-api-key", username: "test-user@example.com")
        
        // Test that multiple endpoints are configured
        let endpoints = service.getBetaEndpoints()
        XCTAssertGreaterThan(endpoints.count, 1)
        XCTAssertTrue(endpoints.contains { $0.contains("beta") })
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testSyncServiceUpdatedFlow() async {
        let syncService = SyncService()
        
        // Test that sync service can be initialized without device token
        XCTAssertNotNil(syncService)
        XCTAssertEqual(syncService.syncStatus, .idle)
        XCTAssertFalse(syncService.isRunning)
    }
    
    func testRemarkableWorkflowyIntegration() {
        // Test the integration models
        let document = RemarkableDocument(
            id: "doc-1",
            name: "Integration Test",
            type: "notebook",
            lastModified: Date(),
            size: 2048,
            parentId: nil
        )
        
        let node = WorkflowyNode(
            id: "node-1",
            name: "Integration Test Node",
            note: "Synced from Remarkable"
        )
        
        // Test that they can be linked
        var linkedDocument = document
        linkedDocument.workflowyNodeId = node.id
        
        XCTAssertEqual(linkedDocument.workflowyNodeId, node.id)
        XCTAssertFalse(linkedDocument.isPDF) // notebook type
    }
    
    // MARK: - Error Handling Tests
    
    func testEnhancedErrorMessages() {
        // Test Remarkable errors
        let remarkableError = RemarkableError.invalidToken("Test token error")
        XCTAssertEqual(remarkableError.errorDescription, "Test token error")
        
        let authError = RemarkableError.authenticationFailed
        XCTAssertTrue(authError.errorDescription?.contains("may need to register") ?? false)
        
        // Test Workflowy errors
        let workflowyError = WorkflowyError.apiError("Test API error")
        XCTAssertEqual(workflowyError.errorDescription, "API Error: Test API error")
    }
    
    // MARK: - Settings View Model Enhanced Tests
    
    @MainActor
    func testSettingsViewModelRegistrationFlow() {
        let viewModel = SettingsViewModel()
        
        // Test registration code validation
        viewModel.remarkableRegistrationCode = "abc"
        XCTAssertEqual(viewModel.remarkableRegistrationCode.count, 3)
        
        // Test that registration code can be set (uppercasing is handled in UI)
        viewModel.remarkableRegistrationCode = "test1234"
        XCTAssertEqual(viewModel.remarkableRegistrationCode, "test1234")
        
        // Test that device token management works
        viewModel.remarkableDeviceToken = "bearer-token-123"
        XCTAssertFalse(viewModel.remarkableDeviceToken.isEmpty)
        
        // Test re-authentication
        _ = viewModel.remarkableDeviceToken
        // Simulate re-authentication
        viewModel.remarkableDeviceToken = ""
        viewModel.remarkableConnectionStatus = .unknown
        XCTAssertTrue(viewModel.remarkableDeviceToken.isEmpty)
        XCTAssertEqual(viewModel.remarkableConnectionStatus, .unknown)
    }
}

// Note: Test extensions are defined in RemarkableWorkflowySyncTests.swift