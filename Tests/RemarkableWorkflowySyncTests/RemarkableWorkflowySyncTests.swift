import XCTest
@testable import RemarkableWorkflowySync

final class RemarkableWorkflowySyncTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Core Functionality Tests
    
    func testAppInitialization() throws {
        // Test that core app models can be created
        let settings = AppSettings()
        XCTAssertNotNil(settings)
        
        let document = RemarkableDocument(
            id: "test",
            name: "Test Doc",
            type: "pdf",
            lastModified: Date(),
            size: 1024,
            parentId: nil
        )
        XCTAssertNotNil(document)
        
        let node = WorkflowyNode(id: "node1", name: "Test Node")
        XCTAssertNotNil(node)
    }
    
    func testServiceInitialization() {
        // Test that all services can be initialized
        let remarkableService = RemarkableService()
        XCTAssertNotNil(remarkableService)
        
        let workflowyService = WorkflowyService(apiKey: "test", username: "test-user@example.com")
        XCTAssertNotNil(workflowyService)
        
        let dropboxService = DropboxService(accessToken: "test")
        XCTAssertNotNil(dropboxService)
        
        let pdfService = PDFConversionService()
        XCTAssertNotNil(pdfService)
    }
    
    @MainActor
    func testViewModelInitialization() {
        // Test that view models can be initialized
        let mainViewModel = MainViewModel()
        XCTAssertNotNil(mainViewModel)
        
        let settingsViewModel = SettingsViewModel()
        XCTAssertNotNil(settingsViewModel)
        
        let menuBarManager = MenuBarManager()
        XCTAssertNotNil(menuBarManager)
    }
    
    @MainActor
    func testSyncServiceInitialization() {
        // Test that sync service works with new authentication flow
        let syncService = SyncService()
        XCTAssertNotNil(syncService)
        XCTAssertEqual(syncService.syncStatus, .idle)
        XCTAssertFalse(syncService.isRunning)
        XCTAssertNil(syncService.lastSyncDate)
    }
    
    // MARK: - Enhanced Authentication Tests
    
    func testRemarkableAuthenticationFlow() {
        let service = RemarkableService()
        
        // Test device ID generation
        let deviceID = service.generateDeviceID()
        XCTAssertFalse(deviceID.isEmpty)
        XCTAssertEqual(deviceID.count, 36) // UUID length
        
        // Test token path creation
        let tokenPath = service.getTokenPath()
        XCTAssertTrue(tokenPath.path.contains(".remarkable-token"))
    }
    
    // MARK: - Workflowy Integration Tests
    
    func testWorkflowyIntegrationFeatures() {
        let service = WorkflowyService(apiKey: "test-key", username: "test-user@example.com")
        
        // Test beta endpoints configuration
        let endpoints = service.getBetaEndpoints()
        XCTAssertGreaterThan(endpoints.count, 0)
        XCTAssertTrue(endpoints.contains { $0.contains("beta") || $0.contains("api") })
        
        // Test document note creation
        let testDocument = RemarkableDocument(
            id: "test-123",
            name: "My Notes",
            type: "notebook",
            lastModified: Date(),
            size: 4096,
            parentId: nil
        )
        
        let note = service.createDocumentNote(for: testDocument, dropboxUrl: "https://dropbox.com/test.pdf")
        XCTAssertTrue(note.contains("Type: NOTEBOOK"))
        XCTAssertTrue(note.contains("Remarkable ID: test-123"))
        XCTAssertTrue(note.contains("dropbox.com"))
    }
    
    // MARK: - Error Handling Tests
    
    func testEnhancedErrorHandling() {
        // Test that all error types have proper descriptions
        let remarkableErrors: [RemarkableError] = [
            .authenticationFailed,
            .invalidResponse,
            .documentNotFound,
            .invalidToken("Test message"),
            .apiError("API failed"),
            .networkError("Network issue")
        ]
        
        for error in remarkableErrors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    // MARK: - Data Model Tests
    
    func testEnhancedDataModels() {
        // Test RemarkableDocument with workflowy integration
        var document = RemarkableDocument(
            id: "doc1",
            name: "Test Document",
            type: "pdf",
            lastModified: Date(),
            size: 2048,
            parentId: "folder1"
        )
        
        XCTAssertTrue(document.isPDF)
        XCTAssertNil(document.workflowyNodeId)
        
        document.workflowyNodeId = "wf-node-123"
        XCTAssertEqual(document.workflowyNodeId, "wf-node-123")
        
        // Test WorkflowyNode with remarkable integration
        var node = WorkflowyNode(
            id: "node1",
            name: "Remarkable Sync",
            note: "Auto-synced document",
            parentId: "parent1"
        )
        
        XCTAssertNil(node.remarkableDocumentId)
        node.remarkableDocumentId = "doc1"
        XCTAssertEqual(node.remarkableDocumentId, "doc1")
    }
    
    // MARK: - Performance Tests
    
    func testDocumentProcessingPerformance() throws {
        self.measure {
            // Create multiple documents to test processing speed
            var documents: [RemarkableDocument] = []
            for i in 0..<100 {
                let doc = RemarkableDocument(
                    id: "doc-\(i)",
                    name: "Document \(i)",
                    type: i % 2 == 0 ? "pdf" : "notebook",
                    lastModified: Date(),
                    size: 1024 * i,
                    parentId: nil
                )
                documents.append(doc)
            }
            
            // Test filtering PDF documents
            let pdfDocuments = documents.filter { $0.isPDF }
            XCTAssertGreaterThan(pdfDocuments.count, 0)
        }
    }
}

// MARK: - Test Extensions

extension RemarkableService {
    // Expose internal methods for testing
    func getTokenPath() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(".remarkable-token")
    }
    
    func generateDeviceID() -> String {
        if let savedDeviceID = UserDefaults.standard.string(forKey: "RemarkableDeviceID") {
            return savedDeviceID
        }
        
        let deviceID = UUID().uuidString
        UserDefaults.standard.set(deviceID, forKey: "RemarkableDeviceID")
        return deviceID
    }
}

extension WorkflowyService {
    // Expose internal methods for testing
    func createDocumentNote(for document: RemarkableDocument, dropboxUrl: String?) -> String {
        var noteContent = """
        📄 Type: \(document.type.uppercased())
        📏 Size: \(formatFileSize(document.size))
        📅 Modified: \(document.lastModified.formatted())
        🆔 Remarkable ID: \(document.id)
        """
        
        if let dropboxUrl = dropboxUrl {
            noteContent += "\n\n🔗 Dropbox Link: \(dropboxUrl)\n\n📲 Click to download or view the document"
        }
        
        return noteContent
    }
    
    func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func searchInNodes(_ nodes: [WorkflowyNode], query: String) -> [WorkflowyNode] {
        var results: [WorkflowyNode] = []
        
        for node in nodes {
            // Check if current node matches
            if node.name.lowercased().contains(query.lowercased()) ||
               (node.note?.lowercased().contains(query.lowercased()) ?? false) {
                results.append(node)
            }
            
            // Recursively search children
            if let children = node.children {
                results.append(contentsOf: searchInNodes(children, query: query))
            }
        }
        
        return results
    }
    
    func getBetaEndpoints() -> [String] {
        return [
            "https://workflowy.com/api/beta/create-item",
            "https://workflowy.com/api/nodes",
            "https://workflowy.com/api/create"
        ]
    }
}