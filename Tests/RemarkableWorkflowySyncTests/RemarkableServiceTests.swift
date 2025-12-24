import XCTest
import Alamofire
@testable import RemarkableWorkflowySync

final class RemarkableServiceTests: XCTestCase {
    
    var remarkableService: RemarkableService!
    
    override func setUpWithError() throws {
        remarkableService = RemarkableService()
    }
    
    override func tearDownWithError() throws {
        remarkableService = nil
    }
    
    // MARK: - Initialization Tests
    
    func testRemarkableServiceInitialization() {
        XCTAssertNotNil(remarkableService, "RemarkableService should initialize")
        
        // Test initialization with device token
        let serviceWithToken = RemarkableService(deviceToken: "test-token-123")
        XCTAssertNotNil(serviceWithToken, "RemarkableService should initialize with device token")
    }
    
    // MARK: - Device Registration Tests
    
    func testRegisterDeviceWithValidCode() async throws {
        // Given: Valid 8-character registration code
        let validCode = "abcd1234"
        
        // When: Attempting registration
        do {
            let token = try await remarkableService.registerDevice(code: validCode)
            // If this succeeds, token should be valid
            XCTAssertFalse(token.isEmpty, "Registration should return non-empty token")
            XCTAssertGreaterThan(token.count, 8, "Bearer token should be longer than registration code")
        } catch let error as RemarkableError {
            // Expected to fail with expired/invalid code
            switch error {
            case .apiError(let message):
                XCTAssertTrue(message.contains("registration") || message.contains("500"), 
                             "Should indicate registration failure")
            case .networkError(_), .invalidToken(_):
                XCTAssertTrue(true, "Network or token errors are acceptable")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testRegisterDeviceWithInvalidCode() async throws {
        // Given: Invalid registration codes
        let invalidCodes = ["", "abc", "toolongcode123", "1234567", "123456789"]
        
        for code in invalidCodes {
            // When: Attempting registration with invalid code
            do {
                _ = try await remarkableService.registerDevice(code: code)
                XCTFail("Registration should fail with invalid code: \(code)")
            } catch let error as RemarkableError {
                // Then: Should fail with appropriate error
                switch error {
                case .invalidToken(let message):
                    XCTAssertTrue(message.contains("8 characters"), "Should specify 8-character requirement")
                default:
                    break // Other errors are also acceptable
                }
            }
        }
    }
    
    // MARK: - Authentication Tests
    
    func testValidateConnectionWithoutToken() async throws {
        // Given: Service without bearer token
        
        // When: Validating connection
        let isValid = try await remarkableService.validateConnection()
        
        // Then: Should return false without token
        XCTAssertFalse(isValid, "Connection should be invalid without bearer token")
    }
    
    func testValidateConnectionWithInvalidToken() async throws {
        // Given: Service with invalid token
        // First register with fake token to simulate having a token
        let serviceWithFakeToken = RemarkableService(deviceToken: "fake-token-123")
        
        // When: Validating connection
        do {
            let isValid = try await serviceWithFakeToken.validateConnection()
            XCTAssertFalse(isValid, "Connection should be invalid with fake token")
        } catch {
            // Also acceptable for this to throw an error
            XCTAssertTrue(error is RemarkableError, "Should throw RemarkableError")
        }
    }
    
    // MARK: - Document Operations Tests
    
    func testFetchDocumentsWithoutAuth() async throws {
        // Given: Service without authentication
        
        // When: Attempting to fetch documents
        do {
            _ = try await remarkableService.fetchDocuments()
            XCTFail("Should fail to fetch documents without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    func testDownloadDocumentWithoutAuth() async throws {
        // Given: Service without authentication and document ID
        let documentId = "test-document-123"
        
        // When: Attempting to download document
        do {
            _ = try await remarkableService.downloadDocument(id: documentId)
            XCTFail("Should fail to download document without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    func testGetDocumentMetadataWithoutAuth() async throws {
        // Given: Service without authentication
        let documentId = "metadata-test-123"
        
        // When: Attempting to get metadata
        do {
            _ = try await remarkableService.getDocumentMetadata(id: documentId)
            XCTFail("Should fail to get metadata without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    // MARK: - Folder Creation Tests (New Functionality)
    
    func testCreateFolderWithoutAuth() async throws {
        // Given: Service without authentication
        let folderName = "Test Folder"
        
        // When: Attempting to create folder
        do {
            _ = try await remarkableService.createFolder(name: folderName)
            XCTFail("Should fail to create folder without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    func testCreateFolderWithParent() async throws {
        // Given: Service without auth (will fail) and parent folder
        let folderName = "Child Folder"
        let parentId = "parent-folder-123"
        
        // When: Attempting to create child folder
        do {
            _ = try await remarkableService.createFolder(name: folderName, parentId: parentId)
            XCTFail("Should fail without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with auth error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    func testCreateWorkflowyFolder() async throws {
        // Test creating the specific WORKFLOWY folder
        let workflowyFolderName = "WORKFLOWY"
        
        do {
            _ = try await remarkableService.createFolder(name: workflowyFolderName)
            XCTFail("Should fail without authentication")
        } catch let error as RemarkableError {
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    // MARK: - Upload Operations Tests
    
    func testUploadPDFWithoutAuth() async throws {
        // Given: PDF data and service without auth
        let pdfData = createTestPDFData()
        let fileName = "test-upload.pdf"
        
        // When: Attempting to upload PDF
        do {
            _ = try await remarkableService.uploadPDF(data: pdfData, name: fileName)
            XCTFail("Should fail to upload PDF without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    func testUploadPDFWithParentFolder() async throws {
        // Given: PDF data with parent folder
        let pdfData = createTestPDFData()
        let fileName = "child-document.pdf"
        let parentFolderId = "workflowy-folder-123"
        
        // When: Attempting to upload to specific folder
        do {
            _ = try await remarkableService.uploadPDF(data: pdfData, name: fileName, parentId: parentFolderId)
            XCTFail("Should fail without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    // MARK: - Delete Operations Tests
    
    func testDeleteDocumentWithoutAuth() async throws {
        // Given: Document ID and service without auth
        let documentId = "delete-test-123"
        
        // When: Attempting to delete document
        do {
            try await remarkableService.deleteDocument(id: documentId)
            XCTFail("Should fail to delete document without authentication")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    // MARK: - Token Management Tests
    
    func testRefreshTokenWithoutCurrentToken() async throws {
        // Given: Service without bearer token
        
        // When: Attempting to refresh token
        do {
            _ = try await remarkableService.refreshToken()
            XCTFail("Should fail to refresh token without current token")
        } catch let error as RemarkableError {
            // Then: Should fail with authentication error
            XCTAssertEqual(error, .authenticationFailed, "Should fail with authentication error")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testRemarkableErrorDescriptions() {
        // Test all RemarkableError cases have proper descriptions
        let authError = RemarkableError.authenticationFailed
        let responseError = RemarkableError.invalidResponse
        let notFoundError = RemarkableError.documentNotFound
        let networkError = RemarkableError.networkError("Test network error")
        let tokenError = RemarkableError.invalidToken("Test token error")
        let apiError = RemarkableError.apiError("Test API error")
        
        XCTAssertNotNil(authError.errorDescription)
        XCTAssertNotNil(responseError.errorDescription)
        XCTAssertNotNil(notFoundError.errorDescription)
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertNotNil(tokenError.errorDescription)
        XCTAssertNotNil(apiError.errorDescription)
        
        XCTAssertTrue(networkError.errorDescription?.contains("Test network error") == true)
        XCTAssertTrue(tokenError.errorDescription?.contains("Test token error") == true)
        XCTAssertTrue(apiError.errorDescription?.contains("Test API error") == true)
    }
    
    func testRemarkableErrorEquality() {
        // Test error equality for specific cases
        let authError1 = RemarkableError.authenticationFailed
        let authError2 = RemarkableError.authenticationFailed
        
        XCTAssertEqual(authError1, authError2, "Same error types should be equal")
        
        let responseError = RemarkableError.invalidResponse
        XCTAssertNotEqual(authError1, responseError, "Different error types should not be equal")
    }
    
    // MARK: - Service Discovery Tests
    
    func testServiceDiscoveryWithoutAuth() async throws {
        // The service discovery is internal, but we can test it indirectly
        // by checking that operations handle the discovery process
        
        // When validation is attempted, it should go through service discovery
        let isValid = try await remarkableService.validateConnection()
        
        // Should handle discovery failure gracefully
        XCTAssertFalse(isValid, "Should handle service discovery failure gracefully")
    }
    
    // MARK: - Integration Tests for New Folder Functionality
    
    func testWorkflowyFolderCreationWorkflow() async throws {
        // This tests the workflow that SyncService would use
        
        // Step 1: Try to create WORKFLOWY folder (will fail due to auth)
        do {
            let folderId = try await remarkableService.createFolder(name: "WORKFLOWY")
            XCTFail("Should fail without auth, but if it succeeds, folderId should be valid")
        } catch {
            // Expected failure
        }
        
        // Step 2: Try to upload PDF to that folder (will also fail)
        do {
            let pdfData = createTestPDFData()
            _ = try await remarkableService.uploadPDF(data: pdfData, name: "Workflowy_Export", parentId: "folder-id")
            XCTFail("Should fail without auth")
        } catch {
            // Expected failure
        }
    }
    
    // MARK: - Performance Tests
    
    func testMultipleFolderCreationPerformance() {
        // Test creating multiple folders in sequence
        let folderNames = ["Folder1", "Folder2", "Folder3", "WORKFLOWY", "TestFolder"]
        
        measure {
            Task {
                for folderName in folderNames {
                    do {
                        _ = try await remarkableService.createFolder(name: folderName)
                    } catch {
                        // Expected to fail, but should fail quickly
                    }
                }
            }
        }
    }
    
    func testLargePDFUploadPerformance() {
        // Test uploading larger PDF data
        let largePDFData = createLargeTestPDFData()
        
        measure {
            Task {
                do {
                    _ = try await remarkableService.uploadPDF(data: largePDFData, name: "LargeTest.pdf")
                } catch {
                    // Expected to fail due to auth, but should handle large data efficiently
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestPDFData() -> Data {
        // Create minimal PDF data for testing
        let pdfString = "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj xref 0 4 0000000000 65535 f 0000000009 00000 n 0000000058 00000 n 0000000115 00000 n trailer<</Size 4/Root 1 0 R>>startxref 190 %%EOF"
        return pdfString.data(using: .utf8) ?? Data()
    }
    
    private func createLargeTestPDFData() -> Data {
        // Create larger test data (simulating a real PDF)
        let baseData = createTestPDFData()
        let padding = Data(repeating: 0x20, count: 1024 * 100) // 100KB of padding
        return baseData + padding
    }
    
    private func createTestDocument() -> RemarkableDocument {
        return RemarkableDocument(
            id: "remarkable-test-123",
            name: "Test Remarkable Document",
            type: "DocumentType",
            lastModified: Date(),
            size: 2048,
            parentId: nil
        )
    }
}