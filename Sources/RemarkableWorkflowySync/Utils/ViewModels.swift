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
            let remarkableService = RemarkableService()
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
    
    func syncWorkflowyToRemarkable() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await syncService.syncCompleteWorkflowyOutline()
            print("✅ Successfully synced Workflowy outline to Remarkable")
        } catch {
            print("❌ Failed to sync Workflowy outline: \(error.localizedDescription)")
            // Show error to user via syncStatus
            syncStatus = .error(error.localizedDescription)
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var remarkableUsername = ""
    @Published var workflowyUsername = ""
    @Published var dropboxUsername = ""
    @Published var remarkableDeviceToken = ""
    @Published var remarkableRegistrationCode = ""
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
        remarkableUsername = settings.remarkableUsername
        workflowyUsername = settings.workflowyUsername
        dropboxUsername = settings.dropboxUsername
        remarkableDeviceToken = settings.remarkableDeviceToken
        workflowyApiKey = settings.workflowyApiKey
        dropboxAccessToken = settings.dropboxAccessToken
        syncInterval = settings.syncInterval
        enableBackgroundSync = settings.enableBackgroundSync
        autoConvertToPDF = settings.autoConvertToPDF
    }
    
    func saveSettings() {
        let settings = AppSettings(
            remarkableUsername: remarkableUsername,
            workflowyUsername: workflowyUsername,
            dropboxUsername: dropboxUsername,
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
        // If we only have a registration code, prompt user to register first
        if remarkableDeviceToken.isEmpty && !remarkableRegistrationCode.isEmpty {
            remarkableConnectionStatus = .failed("Please register device first using the registration code")
            return
        }
        
        guard !remarkableDeviceToken.isEmpty else {
            remarkableConnectionStatus = .failed("No bearer token available. Please register device first.")
            return
        }
        
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        do {
            let service = RemarkableService()
            let isValid = try await service.validateConnection()
            remarkableConnectionStatus = isValid ? .connected : .failed("Authentication failed")
        } catch {
            remarkableConnectionStatus = .failed(error.localizedDescription)
        }
    }
    
    func registerRemarkableDevice() async {
        guard remarkableRegistrationCode.count == 8 else {
            remarkableConnectionStatus = .failed("Registration code must be exactly 8 characters")
            return
        }
        
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        do {
            let service = RemarkableService()
            let bearerToken = try await service.registerDevice(code: remarkableRegistrationCode)
            
            // Replace the registration code with the bearer token
            remarkableDeviceToken = bearerToken
            remarkableRegistrationCode = "" // Clear the registration code
            remarkableConnectionStatus = .connected
            
            // Update the api-tokens.md file with the new bearer token
            await updateTokenInFile(newToken: bearerToken)
            
            // Save settings with the bearer token
            saveSettings()
            
            print("✅ Device registered successfully. Bearer token saved.")
        } catch {
            remarkableConnectionStatus = .failed(error.localizedDescription)
            print("❌ Registration failed: \(error.localizedDescription)")
        }
    }
    
    private func updateTokenInFile(newToken: String) async {
        guard let projectRoot = APITokenParser.shared.findProjectRoot() else {
            print("Could not find project root to update token file")
            return
        }
        
        let tokensFilePath = projectRoot.appendingPathComponent("api-tokens.md")
        
        do {
            let content = try String(contentsOf: tokensFilePath, encoding: .utf8)
            
            // Find and replace the remarkable token section
            let lines = content.components(separatedBy: CharacterSet.newlines)
            var newLines: [String] = []
            var inRemarkableSection = false
            let inCodeBlock = false
            var skipNextLines = 0
            
            for line in lines {
                if skipNextLines > 0 {
                    skipNextLines -= 1
                    continue
                }
                
                if line.contains("## Remarkable 2") {
                    inRemarkableSection = true
                    newLines.append(line)
                } else if line.hasPrefix("## ") && inRemarkableSection {
                    inRemarkableSection = false
                    newLines.append(line)
                } else if inRemarkableSection {
                    if line.contains("**Device Token:**") {
                        newLines.append(line)
                        newLines.append("```")
                        newLines.append(newToken)
                        newLines.append("```")
                        // Skip the original code block
                        skipNextLines = 3
                    } else if !line.hasPrefix("```") && !inCodeBlock {
                        newLines.append(line)
                    }
                } else {
                    newLines.append(line)
                }
            }
            
            let newContent = newLines.joined(separator: "\n")
            try newContent.write(to: tokensFilePath, atomically: true, encoding: .utf8)
            print("📝 Updated api-tokens.md with new bearer token")
            
        } catch {
            print("⚠️ Could not update api-tokens.md file: \(error.localizedDescription)")
        }
    }
    
    func testWorkflowyConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        do {
            let service = WorkflowyService(apiKey: workflowyApiKey, username: workflowyUsername.isEmpty ? nil : workflowyUsername)
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
        
        // Load usernames
        if !tokens.remarkableUsername.isEmpty && tokens.remarkableUsername != remarkableUsername {
            remarkableUsername = tokens.remarkableUsername
            tokensUpdated = true
        }
        
        if !tokens.workflowyUsername.isEmpty && tokens.workflowyUsername != workflowyUsername {
            workflowyUsername = tokens.workflowyUsername
            tokensUpdated = true
        }
        
        if !tokens.dropboxUsername.isEmpty && tokens.dropboxUsername != dropboxUsername {
            dropboxUsername = tokens.dropboxUsername
            tokensUpdated = true
        }
        
        // Load tokens
        if !tokens.remarkableToken.isEmpty && tokens.remarkableToken != remarkableDeviceToken {
            // Check if this is an 8-character registration code or a bearer token
            if tokens.remarkableToken.count == 8 {
                // This is a registration code - set it for registration
                remarkableRegistrationCode = tokens.remarkableToken
                print("📋 8-character registration code loaded from file")
            } else {
                // This is likely a bearer token from a previous registration
                remarkableDeviceToken = tokens.remarkableToken
                print("🔑 Bearer token loaded from file")
            }
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