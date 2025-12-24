import Foundation
import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var documents: [RemarkableDocument] = []
    @Published var selectedDocuments: Set<RemarkableDocument.ID> = []
    @Published var syncStatus: SyncStatus = .idle
    @Published var isLoading = false
    
    @MainActor private let syncService = SyncService()
    private let settings = AppSettings.load()
    private var cancellables = Set<AnyCancellable>()
    
    var allDocumentsSelected: Bool {
        !documents.isEmpty && selectedDocuments.count == documents.count
    }
    
    init() {
        syncService.$syncStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.syncStatus, on: self)
            .store(in: &cancellables)
    }
    
    func loadInitialData() async {
        await refreshDocuments()
        
        if settings.enableBackgroundSync {
            syncService.startBackgroundSync()
        }
    }
    
    func refreshDocuments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let remarkableService = RemarkableService(deviceToken: settings.remarkableDeviceToken)
            documents = try await remarkableService.fetchDocuments()
        } catch {
            print("Failed to load documents: \(error)")
            documents = []
        }
    }
    
    func syncSelectedDocuments() async {
        let documentsToSync = selectedDocuments.compactMap { id in
            documents.first { $0.id == id }
        }
        
        do {
            try await syncService.syncDocuments(documentsToSync, direction: .remarkableToWorkflowy)
        } catch {
            print("Sync failed: \(error)")
        }
    }
    
    func toggleSelectAll() {
        if allDocumentsSelected {
            selectedDocuments.removeAll()
        } else {
            selectedDocuments = Set(documents.map(\.id))
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var remarkableDeviceToken = ""
    @Published var workflowyApiKey = ""
    @Published var dropboxAccessToken = ""
    @Published var syncInterval: TimeInterval = 3600
    @Published var enableBackgroundSync = true
    @Published var autoConvertToPDF = true
    @Published var lastSyncDate: Date?
    
    @Published var remarkableConnectionStatus: ConnectionStatus = .unknown
    @Published var workflowyConnectionStatus: ConnectionStatus = .unknown
    @Published var dropboxConnectionStatus: ConnectionStatus = .unknown
    @Published var isTestingConnection = false
    @Published var autoLoadedFromFile = false
    
    var hasValidSettings: Bool {
        !remarkableDeviceToken.isEmpty &&
        !workflowyApiKey.isEmpty
    }
    
    var hasMinimalRequiredSettings: Bool {
        !remarkableDeviceToken.isEmpty ||
        !workflowyApiKey.isEmpty
    }
    
    init() {
        loadSettings()
        loadTokensFromFile()
    }
    
    private func loadSettings() {
        let settings = AppSettings.load()
        remarkableDeviceToken = settings.remarkableDeviceToken
        workflowyApiKey = settings.workflowyApiKey
        dropboxAccessToken = settings.dropboxAccessToken
        syncInterval = settings.syncInterval
        enableBackgroundSync = settings.enableBackgroundSync
        autoConvertToPDF = settings.autoConvertToPDF
    }
    
    func saveSettings() {
        let settings = AppSettings(
            remarkableDeviceToken: remarkableDeviceToken,
            workflowyApiKey: workflowyApiKey,
            dropboxAccessToken: dropboxAccessToken,
            syncInterval: syncInterval,
            enableBackgroundSync: enableBackgroundSync,
            autoConvertToPDF: autoConvertToPDF
        )
        settings.save()
    }
    
    func testRemarkableConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        do {
            let service = RemarkableService(deviceToken: remarkableDeviceToken)
            try await service.authenticate()
            remarkableConnectionStatus = .connected
        } catch {
            remarkableConnectionStatus = .failed(error.localizedDescription)
        }
    }
    
    func testWorkflowyConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        do {
            let service = WorkflowyService(apiKey: workflowyApiKey)
            let isValid = try await service.validateConnection()
            workflowyConnectionStatus = isValid ? .connected : .failed("Invalid API key")
        } catch {
            workflowyConnectionStatus = .failed(error.localizedDescription)
        }
    }
    
    func testDropboxConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        guard !dropboxAccessToken.isEmpty else {
            dropboxConnectionStatus = .failed("No access token")
            return
        }
        
        do {
            let service = DropboxService(accessToken: dropboxAccessToken)
            // Test by trying to get account info
            try await service.getAccountInfo()
            dropboxConnectionStatus = .connected
        } catch {
            dropboxConnectionStatus = .failed(error.localizedDescription)
        }
    }
    
    private func loadTokensFromFile() {
        guard let tokens = APITokenParser.shared.loadTokensFromFile() else {
            print("No tokens loaded from api-tokens.md file")
            return
        }
        
        // Only update if tokens are not empty and different from current values
        var tokensUpdated = false
        
        if !tokens.remarkableToken.isEmpty && tokens.remarkableToken != remarkableDeviceToken {
            remarkableDeviceToken = tokens.remarkableToken
            tokensUpdated = true
        }
        
        if !tokens.workflowyApiKey.isEmpty && tokens.workflowyApiKey != workflowyApiKey {
            workflowyApiKey = tokens.workflowyApiKey
            tokensUpdated = true
        }
        
        if !tokens.dropboxAccessToken.isEmpty && tokens.dropboxAccessToken != dropboxAccessToken {
            dropboxAccessToken = tokens.dropboxAccessToken
            tokensUpdated = true
        }
        
        if tokensUpdated {
            autoLoadedFromFile = true
            print("✅ API tokens loaded from api-tokens.md file")
            
            // Auto-test connections after loading
            Task {
                await testAllConnections()
            }
        }
    }
    
    func testAllConnections() async {
        // Capture token values for use in async context
        let remarkableToken = remarkableDeviceToken
        let workflowyKey = workflowyApiKey
        let dropboxToken = dropboxAccessToken
        
        // Test connections in parallel for faster feedback
        async let remarkableTest: () = {
            if !remarkableToken.isEmpty {
                await testRemarkableConnection()
            }
        }()
        
        async let workflowyTest: () = {
            if !workflowyKey.isEmpty {
                await testWorkflowyConnection()
            }
        }()
        
        async let dropboxTest: () = {
            if !dropboxToken.isEmpty {
                await testDropboxConnection()
            }
        }()
        
        // Wait for all tests to complete
        _ = await (remarkableTest, workflowyTest, dropboxTest)
    }
}

@MainActor
class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    @MainActor private var syncService: SyncService!
    
    override init() {
        super.init()
        syncService = SyncService()
        Task { @MainActor in
            setupMenuBar()
        }
    }
    
    @MainActor private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.text.below.ecg", accessibilityDescription: "Remarkable Workflowy Sync")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        updateMenu()
    }
    
    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button else { return }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarContentView(syncService: syncService))
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open Main Window", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first(where: { $0.contentView is NSHostingView<MainView> }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func syncNow() {
        Task { @MainActor in
            // Trigger manual sync
        }
    }
    
    @objc private func openPreferences() {
        // Open preferences window
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

struct MenuBarContentView: View {
    @ObservedObject var syncService: SyncService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.below.ecg")
                    .foregroundColor(.blue)
                
                Text("Remarkable Sync")
                    .font(.headline)
            }
            
            Divider()
            
            HStack {
                Circle()
                    .fill(syncService.syncStatus.color)
                    .frame(width: 8, height: 8)
                
                Text(syncService.syncStatus.displayText)
                    .font(.caption)
            }
            
            if let lastSync = syncService.lastSyncDate {
                Text("Last sync: \(lastSync.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack {
                Button("Sync Now") {
                    Task {
                        // Trigger sync
                    }
                }
                .buttonStyle(.bordered)
                .disabled(syncService.isRunning)
                
                Spacer()
                
                Button("Open App") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}