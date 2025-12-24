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
            
            ToolbarItem(placement: .automatic) {
                Button("Sync Workflowy → Remarkable") {
                    Task {
                        await viewModel.syncWorkflowyToRemarkable()
                    }
                }
                .disabled(viewModel.isLoading)
                .help("Export complete Workflowy outline as PDF to WORKFLOWY folder on Remarkable")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                onSave: {
                    Task {
                        await viewModel.refreshDocuments()
                        await viewModel.loadWorkflowyData()
                        await viewModel.loadRemarkableFolders()
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
            
            // Show Workflowy section when connected
            if viewModel.workflowyConnectionStatus == .connected {
                workflowySection
            }
            
            // Show Remarkable folders section when connected
            if viewModel.remarkableConnectionStatus == .connected {
                remarkableFoldersSection
            }
            
            // Show documents section (fallback for when not connected to folders view)
            if viewModel.remarkableConnectionStatus != .connected {
                documentsSection
            }
            
            // Show sync configuration when both services are connected
            if viewModel.workflowyConnectionStatus == .connected && viewModel.remarkableConnectionStatus == .connected {
                syncConfigurationSection
            }
            
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
    
    private var workflowySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workflowy Outline")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isLoadingWorkflowy {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if !viewModel.workflowyNodes.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.workflowyNodes, id: \.id) { node in
                            WorkflowyNodeView(node: node, depth: 0)
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else if viewModel.workflowyConnectionStatus == .connected && !viewModel.isLoadingWorkflowy {
                Text("No Workflowy nodes found")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
    
    private var remarkableFoldersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Remarkable Folders")
                    .font(.headline)
                
                Spacer()
                
                Button("Select All") {
                    // Toggle select all folders
                    if viewModel.selectedFolders.isEmpty {
                        selectAllFolders(viewModel.remarkableFolders)
                    } else {
                        viewModel.selectedFolders.removeAll()
                    }
                }
                .font(.caption)
            }
            
            if !viewModel.remarkableFolders.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.remarkableFolders, id: \.id) { folder in
                            RemarkableFolderView(
                                folder: folder,
                                selectedFolders: $viewModel.selectedFolders,
                                onToggleSelection: viewModel.toggleFolderSelection
                            )
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                if !viewModel.selectedFolders.isEmpty {
                    Text("\(viewModel.selectedFolders.count) folders selected for sync")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
            } else if viewModel.remarkableConnectionStatus == .connected && !viewModel.isLoading {
                Text("No folders found")
                    .foregroundColor(.secondary)
                    .font(.caption)
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
    
    private func selectAllFolders(_ folders: [RemarkableFolder]) {
        for folder in folders {
            viewModel.selectedFolders.insert(folder.id)
            selectAllFolders(folder.children)
        }
    }
    
    private var syncConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync Direction")
                    .font(.headline)
                
                Spacer()
            }
            
            Picker("Sync Direction", selection: $viewModel.selectedSyncDirection) {
                ForEach(SyncPair.SyncDirection.allCases, id: \.self) { direction in
                    Text(direction.displayName)
                        .tag(direction)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Choose how documents should sync between Remarkable and Workflowy")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

struct WorkflowyNodeView: View {
    let node: WorkflowyNode
    let depth: Int
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                // Indentation based on depth
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20, height: 1)
                }
                
                // Expand/collapse button for nodes with children
                if let children = node.children, !children.isEmpty {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 16)
                }
                
                // Node content
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.name.isEmpty ? "Untitled" : node.name)
                        .font(.system(.body, design: .default))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let note = node.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
            
            // Show children if expanded
            if isExpanded, let children = node.children, !children.isEmpty {
                ForEach(children, id: \.id) { child in
                    WorkflowyNodeView(node: child, depth: depth + 1)
                }
            }
        }
    }
}

struct RemarkableFolderView: View {
    let folder: RemarkableFolder
    @Binding var selectedFolders: Set<String>
    let onToggleSelection: (String) -> Void
    @State private var isExpanded: Bool = false
    
    var isSelected: Bool {
        selectedFolders.contains(folder.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Expand/collapse button for folders with children
                if !folder.children.isEmpty || !folder.documents.isEmpty {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 16)
                }
                
                // Selection checkbox
                Button(action: {
                    onToggleSelection(folder.id)
                }) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                
                // Folder icon and name
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(folder.name)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                // Document count
                if !folder.documents.isEmpty {
                    Text("\(folder.documents.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.vertical, 2)
            
            // Show children and documents if expanded
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    // Show child folders
                    ForEach(folder.children, id: \.id) { childFolder in
                        RemarkableFolderView(
                            folder: childFolder,
                            selectedFolders: $selectedFolders,
                            onToggleSelection: onToggleSelection
                        )
                        .padding(.leading, 20)
                    }
                    
                    // Show documents in folder
                    ForEach(folder.documents, id: \.id) { document in
                        HStack {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 36, height: 1)
                            
                            Image(systemName: document.isPDF ? "doc.fill" : "note.text")
                                .foregroundColor(document.isPDF ? .red : .gray)
                                .font(.caption)
                            
                            Text(document.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }
}

#Preview {
    MainView()
}