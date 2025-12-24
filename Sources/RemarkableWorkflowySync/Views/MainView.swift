import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingSettings = false
    @State private var hasShownInitialSettingsCheck = false
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationTitle("Remarkable ↔ Workflowy Sync")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings") {
                    showingSettings = true
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await viewModel.refreshDocuments()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            
            ToolbarItem(placement: .automatic) {
                Button("Sync Selected") {
                    Task {
                        await viewModel.syncSelectedDocuments()
                    }
                }
                .disabled(viewModel.selectedDocuments.isEmpty || viewModel.isLoading)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                onSave: {
                    Task {
                        await viewModel.refreshDocuments()
                    }
                },
                isFirstTimeSetup: isFirstTimeSetup
            )
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onAppear {
            if !hasShownInitialSettingsCheck {
                hasShownInitialSettingsCheck = true
                checkForMissingAPIKeys()
            }
        }
    }
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusSection
            
            documentsSection
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 300)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.syncStatus.color)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.syncStatus.displayText)
                    .font(.caption)
                    .foregroundColor(viewModel.syncStatus.color)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Remarkable Documents")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.toggleSelectAll()
                }) {
                    Text(viewModel.allDocumentsSelected ? "Deselect All" : "Select All")
                        .font(.caption)
                }
            }
            
            if !AppSettings.load().remarkableDeviceToken.isEmpty && viewModel.documents.isEmpty && !viewModel.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No documents found")
                        .font(.headline)
                    Text("Check your API settings and connection.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if AppSettings.load().remarkableDeviceToken.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gear")
                        .foregroundColor(.blue)
                        .font(.largeTitle)
                    Text("Setup Required")
                        .font(.headline)
                    Text("Click Settings to configure your API keys.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Settings") {
                        showingSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding()
            } else {
                List(viewModel.documents, selection: $viewModel.selectedDocuments) { document in
                    DocumentRowView(document: document)
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var detailView: some View {
        VStack {
            if viewModel.selectedDocuments.isEmpty {
                ContentUnavailableView(
                    "No Documents Selected",
                    systemImage: "doc.text",
                    description: Text("Select documents from the sidebar to configure sync settings")
                )
            } else {
                SyncConfigurationView(
                    selectedDocuments: viewModel.selectedDocuments.compactMap { id in
                        viewModel.documents.first { $0.id == id }
                    },
                    onSync: {
                        Task {
                            await viewModel.syncSelectedDocuments()
                        }
                    }
                )
            }
        }
    }
    
    private func checkForMissingAPIKeys() {
        if needsAPISetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingSettings = true
            }
        }
    }
    
    private var isFirstTimeSetup: Bool {
        let settings = AppSettings.load()
        return settings.remarkableDeviceToken.isEmpty && settings.workflowyApiKey.isEmpty
    }
    
    private var needsAPISetup: Bool {
        let settings = AppSettings.load()
        return settings.remarkableDeviceToken.isEmpty || settings.workflowyApiKey.isEmpty
    }
}

struct DocumentRowView: View {
    let document: RemarkableDocument
    
    var body: some View {
        HStack {
            Image(systemName: document.isPDF ? "doc.fill" : "note.text")
                .foregroundColor(document.isPDF ? .red : .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack {
                    Text(document.type.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(formatFileSize(document.size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            if document.workflowyNodeId != nil {
                Image(systemName: "link")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    MainView()
}