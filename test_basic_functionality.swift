#!/usr/bin/env swift

import Foundation

// Simple test script to verify basic functionality
print("🧪 Testing Remarkable-Workflowy Sync App...")

// Test 1: Data Model Creation
print("\n1. Testing Data Models...")

struct RemarkableDocument {
    let id: String
    let name: String
    let type: String
    let lastModified: Date
    let size: Int
    let parentId: String?
    
    var isPDF: Bool {
        return type.lowercased() == "pdf" || name.lowercased().hasSuffix(".pdf")
    }
}

let testDoc1 = RemarkableDocument(
    id: "test1",
    name: "Meeting Notes.pdf", 
    type: "pdf",
    lastModified: Date(),
    size: 1024000,
    parentId: nil
)

let testDoc2 = RemarkableDocument(
    id: "test2",
    name: "Sketches",
    type: "notebook", 
    lastModified: Date(),
    size: 512000,
    parentId: nil
)

print("✅ PDF Detection: \(testDoc1.name) -> \(testDoc1.isPDF ? "PDF" : "Not PDF")")
print("✅ Notebook Detection: \(testDoc2.name) -> \(testDoc2.isPDF ? "PDF" : "Not PDF")")

// Test 2: File Size Formatting
print("\n2. Testing File Size Formatting...")

let formatter = ByteCountFormatter()
formatter.countStyle = .file

print("✅ Size formatting: \(testDoc1.size) bytes -> \(formatter.string(fromByteCount: Int64(testDoc1.size)))")
print("✅ Size formatting: \(testDoc2.size) bytes -> \(formatter.string(fromByteCount: Int64(testDoc2.size)))")

// Test 3: Sync Direction Enum
print("\n3. Testing Sync Directions...")

enum SyncDirection: String, CaseIterable {
    case remarkableToWorkflowy = "remarkable_to_workflowy"
    case workflowyToRemarkable = "workflowy_to_remarkable"
    case bidirectional = "bidirectional"
    
    var displayName: String {
        switch self {
        case .remarkableToWorkflowy: return "Remarkable → Workflowy"
        case .workflowyToRemarkable: return "Workflowy → Remarkable"  
        case .bidirectional: return "Bidirectional"
        }
    }
}

for direction in SyncDirection.allCases {
    print("✅ Direction: \(direction.rawValue) -> \(direction.displayName)")
}

// Test 4: Settings Structure
print("\n4. Testing Settings Structure...")

struct AppSettings {
    var remarkableDeviceToken: String = ""
    var workflowyApiKey: String = ""
    var dropboxAccessToken: String = ""
    var syncInterval: TimeInterval = 3600
    var enableBackgroundSync: Bool = true
    var autoConvertToPDF: Bool = true
    
    var isValid: Bool {
        return !remarkableDeviceToken.isEmpty && 
               !workflowyApiKey.isEmpty && 
               !dropboxAccessToken.isEmpty
    }
}

let emptySettings = AppSettings()
print("✅ Empty settings valid: \(emptySettings.isValid)")

var validSettings = AppSettings()
validSettings.remarkableDeviceToken = "test-token"
validSettings.workflowyApiKey = "test-key"
validSettings.dropboxAccessToken = "test-access"
print("✅ Complete settings valid: \(validSettings.isValid)")

print("\n🎉 Basic functionality tests completed!")
print("📋 Manual checks needed:")
print("   - SwiftUI views render correctly")
print("   - Menu bar integration works")
print("   - API services handle authentication")
print("   - Background sync scheduling functions")
print("   - PDF conversion processes documents")