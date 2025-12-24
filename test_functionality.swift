#!/usr/bin/env swift

import Foundation

// Import the RemarkableWorkflowySync module
import RemarkableWorkflowySync

print("🧪 Testing New Functionality")
print(String(repeating: "=", count: 50))

// Test 1: PDF Generator
print("\n📄 Testing PDF Generator...")
do {
    let pdfGenerator = PDFGenerator()
    
    // Create test nodes
    let testNodes = [
        WorkflowyNode(
            id: "test-1",
            name: "Test Section 1",
            note: "This is a test note for section 1",
            parentId: nil,
            children: [
                WorkflowyNode(
                    id: "test-1-1",
                    name: "Subsection 1.1",
                    note: "Nested content",
                    parentId: "test-1",
                    children: nil
                )
            ]
        ),
        WorkflowyNode(
            id: "test-2",
            name: "Test Section 2",
            note: "This is a test note for section 2",
            parentId: nil,
            children: nil
        )
    ]
    
    print("✅ Created test nodes: \(testNodes.count)")
    
    // Generate PDF (this will test the async functionality)
    let pdfData = try await pdfGenerator.generateWorkflowyPDF(from: testNodes, title: "Test Export")
    
    print("✅ PDF generated successfully: \(pdfData.count) bytes")
    
    // Test navigation PDF
    let navPDFData = try await pdfGenerator.generateWorkflowyNavigationPDF(from: testNodes)
    
    print("✅ Navigation PDF generated: \(navPDFData.count) bytes")
    
} catch {
    print("❌ PDF Generator test failed: \(error)")
}

// Test 2: Service Initialization
print("\n🔧 Testing Service Initialization...")
do {
    let remarkableService = RemarkableService()
    print("✅ RemarkableService initialized")
    
    let workflowyService = WorkflowyService(apiKey: "test-key", username: "test-user@example.com")
    print("✅ WorkflowyService initialized")
    
    let dropboxService = DropboxService(accessToken: "test-token")
    print("✅ DropboxService initialized")
    
    // Test sync service
    await MainActor.run {
        let syncService = SyncService()
        print("✅ SyncService initialized")
    }
    
} catch {
    print("❌ Service initialization failed: \(error)")
}

// Test 3: Error Handling
print("\n⚠️ Testing Error Handling...")
do {
    let remarkableError = RemarkableError.authenticationFailed
    let workflowyError = WorkflowyError.invalidResponse
    let syncError = SyncError.emptyWorkflowyOutline
    
    print("✅ RemarkableError: \(remarkableError.errorDescription ?? "No description")")
    print("✅ WorkflowyError: \(workflowyError.errorDescription ?? "No description")")
    print("✅ SyncError: \(syncError.errorDescription ?? "No description")")
    
} catch {
    print("❌ Error handling test failed: \(error)")
}

// Test 4: Model Creation
print("\n📝 Testing Model Creation...")
do {
    let document = RemarkableDocument(
        id: "test-doc",
        name: "Test Document",
        type: "DocumentType",
        lastModified: Date(),
        size: 1024,
        parentId: nil
    )
    
    print("✅ RemarkableDocument created: \(document.name)")
    
    let node = WorkflowyNode(
        id: "test-node",
        name: "Test Node",
        note: "Test note",
        parentId: nil,
        children: nil
    )
    
    print("✅ WorkflowyNode created: \(node.name)")
    
    let settings = AppSettings(
        remarkableDeviceToken: "test-token",
        workflowyApiKey: "test-key",
        dropboxAccessToken: "test-dropbox",
        syncInterval: 3600,
        enableBackgroundSync: true,
        autoConvertToPDF: true
    )
    
    print("✅ AppSettings created with interval: \(settings.syncInterval)")
    
} catch {
    print("❌ Model creation failed: \(error)")
}

print("\n🏁 Functionality tests completed!")
print("Note: Network operations not tested due to authentication requirements")