import XCTest
@testable import RemarkableWorkflowySync

final class ServiceTests: XCTestCase {
    
    func testRemarkableServiceInitialization() {
        let service = RemarkableService()
        XCTAssertNotNil(service)
    }
    
    func testRemarkableServiceWithDeviceToken() {
        let service = RemarkableService(deviceToken: "test-token")
        XCTAssertNotNil(service)
    }
    
    func testWorkflowyServiceInitialization() {
        let service = WorkflowyService(apiKey: "test-api-key")
        XCTAssertNotNil(service)
    }
    
    func testDropboxServiceInitialization() {
        let service = DropboxService(accessToken: "test-token")
        XCTAssertNotNil(service)
    }
    
    func testSimplePDFServiceTextToPDF() {
        let pdfService = SimplePDFService()
        let testText = "This is a test document for PDF conversion."
        let title = "Test Document"
        
        let pdfData = pdfService.createPDFFromText(testText, title: title)
        
        XCTAssertNotNil(pdfData)
        XCTAssertGreaterThan(pdfData?.count ?? 0, 0)
        
        // Basic PDF validation - should start with PDF header
        if let data = pdfData, data.count > 4 {
            let header = String(data: data.prefix(4), encoding: .ascii)
            XCTAssertEqual(header, "%PDF")
        }
    }
    
    func testPDFConversionServiceInitialization() {
        let service = PDFConversionService()
        XCTAssertNotNil(service)
    }
    
    func testDropboxErrorTypes() {
        let errors: [DropboxError] = [
            .invalidRequest,
            .uploadFailed,
            .shareLinkFailed,
            .deleteFailed,
            .listFailed,
            .authenticationFailed,
            .networkError("Test error")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testRemarkableErrorTypes() {
        let errors: [RemarkableError] = [
            .authenticationFailed,
            .invalidResponse,
            .documentNotFound,
            .networkError("Test error"),
            .invalidToken("Invalid token format"),
            .apiError("API call failed")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testWorkflowyErrorTypes() {
        let errors: [WorkflowyError] = [
            .authenticationFailed,
            .invalidResponse,
            .apiError("API error"),
            .nodeNotFound,
            .rateLimited
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testPDFConversionErrorTypes() {
        let errors: [PDFConversionError] = [
            .unsupportedFormat("unknown"),
            .conversionFailed("Test failure"),
            .invalidData,
            .fileNotFound
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testDropboxFileInitialization() {
        let file = DropboxFile(
            name: "test.pdf",
            path: "/Documents/test.pdf",
            isFolder: false,
            size: 1024,
            lastModified: Date()
        )
        
        XCTAssertEqual(file.name, "test.pdf")
        XCTAssertEqual(file.path, "/Documents/test.pdf")
        XCTAssertFalse(file.isFolder)
        XCTAssertEqual(file.size, 1024)
        XCTAssertNotNil(file.lastModified)
    }
}