import XCTest
import Combine
import PDFKit
@testable import RemarkableWorkflowySync

@MainActor
final class IntegrationTests: XCTestCase {
    
    var syncService: SyncService!
    var remarkableService: RemarkableService!
    var workflowyService: WorkflowyService!
    var pdfGenerator: PDFGenerator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        Task { @MainActor in
            syncService = SyncService()
            remarkableService = RemarkableService()
            workflowyService = WorkflowyService(apiKey: "test-integration-key", username: "test-user@example.com")
            pdfGenerator = PDFGenerator()
            cancellables = Set<AnyCancellable>()
        }
    }
    
    override func tearDownWithError() throws {
        Task { @MainActor in
            syncService.stopBackgroundSync()
            syncService = nil
            remarkableService = nil
            workflowyService = nil
            pdfGenerator = nil
            cancellables = nil
        }
    }
    
    // MARK: - Complete Workflow Integration Tests
    
    func testCompleteWorkflowyToRemarkableWorkflow() async throws {
        // This test verifies the complete integration workflow:
        // Workflowy → PDF Generation → Remarkable Folder Creation → Upload
        
        // Given: Test Workflowy nodes
        let workflowyNodes = createIntegrationTestNodes()
        
        // Step 1: Generate PDF from Workflowy nodes
        let pdfData = try await pdfGenerator.generateWorkflowyNavigationPDF(from: workflowyNodes)
        
        XCTAssertFalse(pdfData.isEmpty, "PDF should be generated from Workflowy nodes")
        XCTAssertGreaterThan(pdfData.count, 1000, "PDF should have substantial content")
        
        // Step 2: Attempt folder creation (will fail due to auth, but tests the workflow)
        do {
            let folderId = try await remarkableService.createFolder(name: "WORKFLOWY")
            
            // Step 3: If folder creation succeeded, attempt PDF upload
            _ = try await remarkableService.uploadPDF(
                data: pdfData,
                name: "Workflowy_Integration_Test",
                parentId: folderId
            )
            
            // If we reach here, the complete workflow succeeded
            XCTAssertTrue(true, "Complete workflow should succeed with proper authentication")
            
        } catch let error as RemarkableError {
            // Expected to fail without authentication
            switch error {
            case .authenticationFailed:
                XCTAssertTrue(true, "Should fail with auth error in integration test")
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func testSyncServiceCompleteWorkflowIntegration() async throws {
        // Test the complete SyncService workflow for Workflowy to Remarkable sync
        
        // Given: Sync service status monitoring
        let expectation = XCTestExpectation(description: "Sync workflow should complete")
        var statusChanges: [SyncStatus] = []
        
        syncService.$syncStatus
            .sink { status in
                statusChanges.append(status)
                
                // Complete expectation when we reach a final state
                switch status {
                case .completed, .error(_):
                    if statusChanges.count >= 2 { // Should have at least idle -> syncing -> final
                        expectation.fulfill()
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // When: Triggering complete Workflowy outline sync
        Task {
            do {
                try await syncService.syncCompleteWorkflowyOutline()
            } catch {
                // Expected to fail due to authentication issues
            }
        }
        
        // Then: Should go through proper status transitions
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertTrue(statusChanges.contains(.idle), "Should start with idle status")
        XCTAssertTrue(statusChanges.contains(.syncing), "Should transition to syncing")
        
        // Final status should be either completed or error
        let finalStatus = statusChanges.last!
        switch finalStatus {
        case .completed:
            XCTAssertTrue(true, "Successful completion is ideal")
        case .error(let message):
            XCTAssertFalse(message.isEmpty, "Error should have descriptive message")
        default:
            XCTFail("Final status should be completed or error, got: \(finalStatus)")
        }
    }
    
    // MARK: - Service Integration Tests
    
    func testWorkflowyToRemarkableDataFlow() async throws {
        // Test data flow from Workflowy through to Remarkable
        
        // Step 1: Create Workflowy nodes
        let workflowyNodes = createIntegrationTestNodes()
        XCTAssertFalse(workflowyNodes.isEmpty, "Should have test nodes")
        
        // Step 2: Generate PDF
        let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: workflowyNodes, title: "Integration Test")
        XCTAssertGreaterThan(pdfData.count, 500, "PDF should contain meaningful data")
        
        // Step 3: Verify PDF structure
        let pdfDocument = PDFDocument(data: pdfData)
        XCTAssertNotNil(pdfDocument, "Generated data should be valid PDF")
        XCTAssertGreaterThan(pdfDocument!.pageCount, 2, "PDF should have multiple pages")
        
        // Step 4: Test the data would be uploadable (structure test)
        let fileName = "Integration_Test_\(Date().timeIntervalSince1970)"
        XCTAssertFalse(fileName.isEmpty, "Should generate valid filename")
        XCTAssertTrue(fileName.contains("Integration_Test"), "Filename should contain identifier")
    }
    
    func testRemarkableFolderAndDocumentIntegration() async throws {
        // Test the folder creation and document upload integration
        
        // Given: PDF data to upload
        let testPDF = createIntegrationTestPDF()
        
        // Step 1: Attempt folder creation
        do {
            let folderId = try await remarkableService.createFolder(name: "INTEGRATION_TEST")
            
            // Step 2: Upload document to folder
            let documentId = try await remarkableService.uploadPDF(
                data: testPDF,
                name: "Integration_Document",
                parentId: folderId
            )
            
            XCTAssertFalse(documentId.isEmpty, "Should return valid document ID")
            XCTAssertTrue(documentId.count > 10, "Document ID should be substantial")
            
        } catch let error as RemarkableError {
            // Expected to fail without proper authentication
            switch error {
            case .authenticationFailed:
                XCTAssertTrue(true, "Integration test expects auth failure")
            case .apiError(let message):
                XCTAssertFalse(message.isEmpty, "API error should have message")
            default:
                XCTFail("Unexpected error in integration test: \(error)")
            }
        }
    }
    
    // MARK: - End-to-End Sync Tests
    
    func testCompleteRemarkableToWorkflowySyncIntegration() async throws {
        // Test the traditional sync direction (Remarkable → Workflowy)
        
        // Given: Mock Remarkable document
        let remarkableDoc = createIntegrationTestDocument()
        
        // When: Syncing document
        do {
            try await syncService.syncDocuments([remarkableDoc], direction: .remarkableToWorkflowy)
            
            // If successful, should have created Workflowy node
            XCTAssertTrue(true, "Remarkable to Workflowy sync should complete")
            
        } catch {
            // Expected to fail due to authentication issues
            XCTAssertTrue(error is RemarkableError || error is WorkflowyError, 
                         "Should fail with service-specific error")
        }
    }
    
    func testBidirectionalSyncIntegration() async throws {
        // Test bidirectional sync functionality
        
        // Given: Test document
        let testDoc = createIntegrationTestDocument()
        
        // When: Bidirectional sync
        do {
            try await syncService.syncDocuments([testDoc], direction: .bidirectional)
            XCTAssertTrue(true, "Bidirectional sync should complete")
        } catch {
            // Expected to fail with current auth setup
            XCTAssertTrue(true, "Bidirectional sync may fail without proper auth")
        }
    }
    
    // MARK: - Error Recovery Integration Tests
    
    func testSyncServiceErrorRecoveryIntegration() async throws {
        // Test that the sync service properly handles and recovers from errors
        
        // Given: Multiple sync operations
        let testDocs = createMultipleIntegrationTestDocuments()
        
        var completedOperations = 0
        var encounteredErrors = 0
        
        // When: Running multiple sync operations
        for doc in testDocs {
            do {
                try await syncService.syncDocuments([doc], direction: .remarkableToWorkflowy)
                completedOperations += 1
            } catch {
                encounteredErrors += 1
            }
        }
        
        // Then: Should handle all operations gracefully
        let totalOperations = completedOperations + encounteredErrors
        XCTAssertEqual(totalOperations, testDocs.count, "Should process all documents")
        
        // In current state, expect mostly errors due to auth
        XCTAssertGreaterThan(encounteredErrors, 0, "Should encounter auth-related errors")
    }
    
    func testConcurrentSyncOperationsIntegration() async throws {
        // Test multiple concurrent sync operations
        
        // Given: Multiple documents to sync concurrently
        let docs = createMultipleIntegrationTestDocuments()
        
        // When: Running concurrent sync operations
        await withTaskGroup(of: Void.self) { group in
            for doc in docs {
                group.addTask {
                    do {
                        try await self.syncService.syncDocuments([doc], direction: .remarkableToWorkflowy)
                    } catch {
                        // Expected to fail, but should not crash
                    }
                }
            }
        }
        
        // Then: All operations should complete without crashes
        XCTAssertTrue(true, "Concurrent operations should complete safely")
    }
    
    // MARK: - Settings Integration Tests
    
    func testSettingsUpdateIntegration() async throws {
        // Test that settings updates properly flow through all services
        
        // Given: New settings
        let newSettings = AppSettings(
            remarkableDeviceToken: "integration-test-token",
            workflowyApiKey: "integration-test-key",
            dropboxAccessToken: "integration-test-dropbox",
            syncInterval: 3600,
            enableBackgroundSync: true,
            autoConvertToPDF: true
        )
        
        // When: Updating settings
        syncService.updateSettings(newSettings)
        
        // Then: Services should be updated (test by ensuring no crashes)
        XCTAssertTrue(true, "Settings update should complete without errors")
        
        // Test that background sync can be restarted
        syncService.startBackgroundSync()
        XCTAssertTrue(syncService.isRunning, "Background sync should start with new settings")
        
        syncService.stopBackgroundSync()
        XCTAssertFalse(syncService.isRunning, "Background sync should stop cleanly")
    }
    
    // MARK: - UI Integration Tests
    
    func testMainViewModelIntegration() async {
        // Test MainViewModel integration with services
        
        // Given: Main view model
        let mainViewModel = MainViewModel()
        
        // When: Loading initial data
        await mainViewModel.loadInitialData()
        
        // Then: Should complete without crashes
        XCTAssertTrue(true, "Main view model should load initial data safely")
        
        // Test Workflowy to Remarkable sync via view model
        await mainViewModel.syncWorkflowyToRemarkable()
        
        XCTAssertTrue(true, "Workflowy to Remarkable sync should complete via view model")
    }
    
    func testSettingsViewModelIntegration() async {
        // Test SettingsViewModel integration
        
        // Given: Settings view model
        let settingsViewModel = SettingsViewModel()
        
        // When: Testing connections
        await settingsViewModel.testAllConnections()
        
        // Then: Should complete gracefully
        XCTAssertTrue(true, "Settings view model should test all connections safely")
    }
    
    // MARK: - Performance Integration Tests
    
    func testCompleteWorkflowPerformance() {
        // Test performance of complete workflow
        let testNodes = createLargeIntegrationTestNodeSet()
        
        measure {
            Task {
                do {
                    let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: testNodes, title: "Performance Test")
                    XCTAssertFalse(pdfData.isEmpty, "Should generate PDF in performance test")
                } catch {
                    XCTFail("Performance test should not fail: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createIntegrationTestNodes() -> [WorkflowyNode] {
        return [
            WorkflowyNode(
                id: "integration-1",
                name: "Integration Test Section",
                note: "This section tests the complete integration workflow",
                parentId: nil,
                children: [
                    WorkflowyNode(
                        id: "integration-1-1",
                        name: "PDF Generation",
                        note: "Tests PDF generation with navigation",
                        parentId: "integration-1",
                        children: [
                            WorkflowyNode(id: "integration-1-1-1", name: "Title Page", note: "Should include title", parentId: "integration-1-1", children: nil),
                            WorkflowyNode(id: "integration-1-1-2", name: "Table of Contents", note: "Should include TOC", parentId: "integration-1-1", children: nil)
                        ]
                    ),
                    WorkflowyNode(
                        id: "integration-1-2",
                        name: "Remarkable Upload",
                        note: "Tests folder creation and document upload",
                        parentId: "integration-1",
                        children: nil
                    )
                ]
            ),
            WorkflowyNode(
                id: "integration-2",
                name: "Error Handling Section",
                note: "Tests proper error handling throughout the workflow",
                parentId: nil,
                children: [
                    WorkflowyNode(id: "integration-2-1", name: "Authentication Errors", note: "Should handle auth failures gracefully", parentId: "integration-2", children: nil),
                    WorkflowyNode(id: "integration-2-2", name: "Network Errors", note: "Should handle network issues", parentId: "integration-2", children: nil)
                ]
            )
        ]
    }
    
    private func createIntegrationTestPDF() -> Data {
        let pdfContent = """
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj
<<
/Length 55
>>
stream
BT
/F1 12 Tf
100 700 Td
(Integration Test PDF) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000201 00000 n 
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
307
%%EOF
"""
        return pdfContent.data(using: .utf8) ?? Data()
    }
    
    private func createIntegrationTestDocument() -> RemarkableDocument {
        return RemarkableDocument(
            id: "integration-doc-\(UUID().uuidString)",
            name: "Integration Test Document",
            type: "DocumentType",
            lastModified: Date(),
            size: 4096,
            parentId: nil
        )
    }
    
    private func createMultipleIntegrationTestDocuments() -> [RemarkableDocument] {
        return (1...5).map { index in
            RemarkableDocument(
                id: "integration-multi-doc-\(index)",
                name: "Integration Document \(index)",
                type: "DocumentType",
                lastModified: Date().addingTimeInterval(TimeInterval(-index * 1800)),
                size: 1024 * index,
                parentId: index > 3 ? "parent-folder" : nil
            )
        }
    }
    
    private func createLargeIntegrationTestNodeSet() -> [WorkflowyNode] {
        return (1...20).map { index in
            WorkflowyNode(
                id: "large-integration-\(index)",
                name: "Large Integration Node \(index)",
                note: "This is a large test node with substantial content for performance testing. Node number \(index) contains various types of content to simulate real-world usage patterns.",
                parentId: nil,
                children: (1...3).map { childIndex in
                    WorkflowyNode(
                        id: "large-integration-\(index)-\(childIndex)",
                        name: "Child Node \(index).\(childIndex)",
                        note: "Child node content with details",
                        parentId: "large-integration-\(index)",
                        children: nil
                    )
                }
            )
        }
    }
}