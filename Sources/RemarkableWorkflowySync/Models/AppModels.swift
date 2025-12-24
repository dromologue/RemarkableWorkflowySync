import Foundation
import SwiftUI

struct RemarkableDocument: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let lastModified: Date
    let size: Int
    let parentId: String?
    var isSelected: Bool = false
    var workflowyNodeId: String?
    
    var isPDF: Bool {
        return type.lowercased() == "pdf" || name.lowercased().hasSuffix(".pdf")
    }
}

struct RemarkableFolder: Identifiable, Codable {
    let id: String
    let name: String
    let parentId: String?
    var children: [RemarkableFolder]
    var documents: [RemarkableDocument]
    var isExpanded: Bool = false
    var isSelected: Bool = false
    
    init(id: String, name: String, parentId: String? = nil, children: [RemarkableFolder] = [], documents: [RemarkableDocument] = []) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.children = children
        self.documents = documents
    }
}

struct WorkflowyNode: Identifiable, Codable {
    let id: String
    let name: String
    let note: String?
    let parentId: String?
    let children: [WorkflowyNode]?
    var remarkableDocumentId: String?
    
    init(id: String, name: String, note: String? = nil, parentId: String? = nil, children: [WorkflowyNode]? = nil) {
        self.id = id
        self.name = name
        self.note = note
        self.parentId = parentId
        self.children = children
    }
}

struct SyncPair: Identifiable, Codable {
    let id: UUID
    let remarkableDocument: RemarkableDocument
    let workflowyNode: WorkflowyNode
    let syncDirection: SyncDirection
    let lastSynced: Date?
    
    init(remarkableDocument: RemarkableDocument, workflowyNode: WorkflowyNode, syncDirection: SyncDirection, lastSynced: Date?) {
        self.id = UUID()
        self.remarkableDocument = remarkableDocument
        self.workflowyNode = workflowyNode
        self.syncDirection = syncDirection
        self.lastSynced = lastSynced
    }
    
    enum SyncDirection: String, CaseIterable, Codable {
        case remarkableToWorkflowy = "remarkable_to_workflowy"
        case workflowyToRemarkable = "workflowy_to_remarkable"
        case bidirectional = "bidirectional"
        
        var displayName: String {
            switch self {
            case .remarkableToWorkflowy:
                return "Remarkable → Workflowy"
            case .workflowyToRemarkable:
                return "Workflowy → Remarkable"
            case .bidirectional:
                return "Bidirectional"
            }
        }
    }
}

struct AppSettings: Codable {
    // User credentials
    var remarkableUsername: String = ""
    var workflowyUsername: String = ""
    var dropboxUsername: String = ""
    
    // API tokens
    var remarkableDeviceToken: String = ""
    var workflowyApiKey: String = ""
    var dropboxAccessToken: String = ""
    
    // App settings
    var syncInterval: TimeInterval = 3600 // 1 hour
    var enableBackgroundSync: Bool = true
    var autoConvertToPDF: Bool = true
    
    init(remarkableUsername: String = "", workflowyUsername: String = "", dropboxUsername: String = "", remarkableDeviceToken: String = "", workflowyApiKey: String = "", dropboxAccessToken: String = "", syncInterval: TimeInterval = 3600, enableBackgroundSync: Bool = true, autoConvertToPDF: Bool = true) {
        self.remarkableUsername = remarkableUsername
        self.workflowyUsername = workflowyUsername
        self.dropboxUsername = dropboxUsername
        self.remarkableDeviceToken = remarkableDeviceToken
        self.workflowyApiKey = workflowyApiKey
        self.dropboxAccessToken = dropboxAccessToken
        self.syncInterval = syncInterval
        self.enableBackgroundSync = enableBackgroundSync
        self.autoConvertToPDF = autoConvertToPDF
    }
    
    private static let settingsURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("RemarkableWorkflowySync")
        .appendingPathComponent("settings.json")
    
    static func load() -> AppSettings {
        guard let url = settingsURL,
              let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    func save() {
        guard let url = AppSettings.settingsURL else { return }
        
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url)
        }
    }
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case error(String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .completed:
            return "Completed"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
}