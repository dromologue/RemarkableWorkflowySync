import Foundation
import Combine

@MainActor
class SyncService: ObservableObject {
    @Published var isRunning = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    private var backgroundTask: Task<Void, Never>?
    private var timer: Timer?
    private let settings = AppSettings.load()
    
    private var remarkableService: RemarkableService
    private var workflowyService: WorkflowyService
    private var dropboxService: DropboxService
    private let pdfConversionService = PDFConversionService()
    
    init() {
        remarkableService = RemarkableService(deviceToken: settings.remarkableDeviceToken)
        workflowyService = WorkflowyService(apiKey: settings.workflowyApiKey)
        dropboxService = DropboxService(accessToken: settings.dropboxAccessToken)
    }
    
    func startBackgroundSync() {
        guard !isRunning else { return }
        
        isRunning = true
        scheduleSync()
    }
    
    func stopBackgroundSync() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        backgroundTask?.cancel()
        backgroundTask = nil
    }
    
    private func scheduleSync() {
        timer = Timer.scheduledTimer(withTimeInterval: settings.syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performScheduledSync()
            }
        }
    }
    
    private func performScheduledSync() async {
        guard isRunning else { return }
        
        syncStatus = .syncing
        
        do {
            try await performSync()
            syncStatus = .completed
            lastSyncDate = Date()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if syncStatus != .syncing {
                syncStatus = .idle
            }
        }
    }
    
    func syncDocuments(_ documents: [RemarkableDocument], direction: SyncPair.SyncDirection) async throws {
        syncStatus = .syncing
        
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if syncStatus != .syncing {
                    syncStatus = .idle
                }
            }
        }
        
        for document in documents {
            try await syncSingleDocument(document, direction: direction)
        }
        
        syncStatus = .completed
        lastSyncDate = Date()
    }
    
    private func syncSingleDocument(_ document: RemarkableDocument, direction: SyncPair.SyncDirection) async throws {
        switch direction {
        case .remarkableToWorkflowy:
            try await syncRemarkableToWorkflowy(document)
        case .workflowyToRemarkable:
            try await syncWorkflowyToRemarkable(document)
        case .bidirectional:
            try await syncBidirectional(document)
        }
    }
    
    private func syncRemarkableToWorkflowy(_ document: RemarkableDocument) async throws {
        let documentData = try await remarkableService.downloadDocument(id: document.id)
        
        var pdfData: Data
        var dropboxLink: String?
        
        if document.isPDF {
            pdfData = documentData
        } else {
            pdfData = try await pdfConversionService.convertToPDF(
                remarkableData: documentData,
                documentName: document.name,
                documentType: document.type
            )
            
            dropboxLink = try await dropboxService.uploadFile(
                data: pdfData,
                fileName: "\(document.name).pdf",
                path: "/RemarkableSync"
            )
        }
        
        let nodeNote = createWorkflowyNote(for: document, dropboxLink: dropboxLink)
        
        if let existingNodeId = document.workflowyNodeId {
            try await workflowyService.updateNode(
                id: existingNodeId,
                name: document.name,
                note: nodeNote
            )
        } else {
            _ = try await workflowyService.createNode(
                name: document.name,
                note: nodeNote,
                parentId: nil
            )
        }
    }
    
    private func syncWorkflowyToRemarkable(_ document: RemarkableDocument) async throws {
    }
    
    private func syncBidirectional(_ document: RemarkableDocument) async throws {
        try await syncRemarkableToWorkflowy(document)
    }
    
    private func performSync() async throws {
        let documents = try await remarkableService.fetchDocuments()
        
        let syncPairs = loadSyncPairs()
        
        for syncPair in syncPairs {
            if let document = documents.first(where: { $0.id == syncPair.remarkableDocument.id }) {
                try await syncSingleDocument(document, direction: syncPair.syncDirection)
            }
        }
    }
    
    private func createWorkflowyNote(for document: RemarkableDocument, dropboxLink: String?) -> String {
        var note = "Source: Remarkable 2\n"
        note += "Type: \(document.type.uppercased())\n"
        note += "Size: \(formatFileSize(document.size))\n"
        note += "Last Modified: \(document.lastModified.formatted())\n"
        
        if let dropboxLink = dropboxLink {
            note += "\nPDF Link: \(dropboxLink)"
        }
        
        return note
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func loadSyncPairs() -> [SyncPair] {
        guard let url = getSyncPairsURL(),
              let data = try? Data(contentsOf: url),
              let syncPairs = try? JSONDecoder().decode([SyncPair].self, from: data) else {
            return []
        }
        return syncPairs
    }
    
    func saveSyncPairs(_ syncPairs: [SyncPair]) {
        guard let url = getSyncPairsURL() else { return }
        
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        if let data = try? JSONEncoder().encode(syncPairs) {
            try? data.write(to: url)
        }
    }
    
    private func getSyncPairsURL() -> URL? {
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("RemarkableWorkflowySync")
            .appendingPathComponent("sync_pairs.json")
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        if newSettings.remarkableDeviceToken != settings.remarkableDeviceToken {
            remarkableService = RemarkableService(deviceToken: newSettings.remarkableDeviceToken)
        }
        
        if newSettings.workflowyApiKey != settings.workflowyApiKey {
            workflowyService = WorkflowyService(apiKey: newSettings.workflowyApiKey)
        }
        
        if newSettings.dropboxAccessToken != settings.dropboxAccessToken {
            dropboxService = DropboxService(accessToken: newSettings.dropboxAccessToken)
        }
        
        if isRunning && newSettings.syncInterval != settings.syncInterval {
            stopBackgroundSync()
            startBackgroundSync()
        }
    }
}