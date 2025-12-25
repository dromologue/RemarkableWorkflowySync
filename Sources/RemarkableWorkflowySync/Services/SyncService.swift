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
    private let pdfGenerator = PDFGenerator()
    
    init() {
        // Pass the bearer token from settings to RemarkableService
        remarkableService = RemarkableService(bearerToken: settings.remarkableDeviceToken)
        workflowyService = WorkflowyService(apiKey: settings.workflowyApiKey, username: settings.workflowyUsername.isEmpty ? nil : settings.workflowyUsername)
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
        
        var dropboxLink: String?
        
        // Always convert to PDF and upload to Dropbox for sharing
        let pdfData: Data
        if document.isPDF {
            pdfData = documentData
        } else {
            pdfData = try await pdfConversionService.convertToPDF(
                remarkableData: documentData,
                documentName: document.name,
                documentType: document.type
            )
        }
        
        // Upload to Dropbox for link sharing
        // Ensure the "Remarkable Synch" folder exists
        _ = try await dropboxService.ensureFolderExists(path: "/Remarkable Synch")
        
        dropboxLink = try await dropboxService.uploadFile(
            data: pdfData,
            fileName: "\(document.name).pdf",
            path: "/Remarkable Synch"
        )
        
        // Use new Workflowy integration with Remarkable folder structure
        _ = try await workflowyService.syncRemarkableDocument(document, dropboxUrl: dropboxLink)
    }
    
    private func syncWorkflowyToRemarkable(_ document: RemarkableDocument) async throws {
        // This is for individual document sync - not typically used
        // The main Workflowy to Remarkable sync is done via syncCompleteWorkflowyOutline
        print("⚠️ Individual document sync from Workflowy to Remarkable not implemented")
        print("   Use syncCompleteWorkflowyOutline() for full outline sync")
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
    
    // MARK: - Workflowy to Remarkable Sync
    
    func syncCompleteWorkflowyOutline() async throws {
        syncStatus = .syncing
        
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if syncStatus != .syncing {
                    syncStatus = .idle
                }
            }
        }
        
        do {
            print("🔄 Starting complete Workflowy outline sync")
            
            // Fetch the complete Workflowy outline
            let workflowyNodes = try await workflowyService.fetchRootNodes()
            
            if workflowyNodes.isEmpty {
                print("⚠️ No Workflowy nodes found - either empty outline or API issues")
                throw SyncError.emptyWorkflowyOutline
            }
            
            print("✅ Fetched \(workflowyNodes.count) root nodes from Workflowy")
            
            // Generate PDF from Workflowy outline with navigation
            let pdfData = try await pdfGenerator.generateWorkflowyNavigationPDF(from: workflowyNodes)
            
            print("✅ Generated PDF (\(pdfData.count) bytes) from Workflowy outline")
            
            // Create WORKFLOWY folder on Remarkable and upload PDF
            let documentId = try await createWorkflowyFolderAndUploadPDF(pdfData: pdfData)
            
            print("✅ Successfully synced Workflowy outline to Remarkable as document: \(documentId)")
            
            syncStatus = .completed
            lastSyncDate = Date()
            
        } catch {
            print("❌ Workflowy outline sync failed: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    private func createWorkflowyFolderAndUploadPDF(pdfData: Data) async throws -> String {
        // Check if WORKFLOWY folder already exists
        let documents = try await remarkableService.fetchDocuments()
        let workflowyFolder = documents.first { $0.name == "WORKFLOWY" && $0.type == "CollectionType" }
        
        let parentId: String?
        if let folder = workflowyFolder {
            parentId = folder.id
            print("📁 Using existing WORKFLOWY folder: \(folder.id)")
        } else {
            // Create WORKFLOWY folder
            parentId = try await remarkableService.createFolder(name: "WORKFLOWY")
            print("📁 Created new WORKFLOWY folder: \(parentId ?? "unknown")")
        }
        
        // Generate unique filename with timestamp
        let timestamp = Date().formatted(.dateTime.year().month().day().hour().minute())
        let fileName = "Workflowy_Export_\(timestamp)"
        
        // Upload the PDF to the WORKFLOWY folder
        let documentId = try await remarkableService.uploadPDF(
            data: pdfData,
            name: fileName,
            parentId: parentId
        )
        
        return documentId
    }
    
    func syncWorkflowyOutlineManually() async throws {
        // Manual trigger for Workflowy to Remarkable sync
        try await syncCompleteWorkflowyOutline()
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
        // Update RemarkableService with new bearer token if changed
        if newSettings.remarkableDeviceToken != settings.remarkableDeviceToken {
            remarkableService = RemarkableService(bearerToken: newSettings.remarkableDeviceToken)
        }

        if newSettings.workflowyApiKey != settings.workflowyApiKey {
            workflowyService = WorkflowyService(apiKey: newSettings.workflowyApiKey, username: newSettings.workflowyUsername.isEmpty ? nil : newSettings.workflowyUsername)
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

enum SyncError: Error, LocalizedError {
    case emptyWorkflowyOutline
    case workflowyConnectionFailed
    case remarkableConnectionFailed
    case pdfGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyWorkflowyOutline:
            return "No content found in Workflowy outline"
        case .workflowyConnectionFailed:
            return "Failed to connect to Workflowy API"
        case .remarkableConnectionFailed:
            return "Failed to connect to Remarkable service"
        case .pdfGenerationFailed:
            return "Failed to generate PDF from Workflowy content"
        }
    }
}