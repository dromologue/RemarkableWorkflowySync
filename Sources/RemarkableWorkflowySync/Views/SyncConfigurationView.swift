import SwiftUI

struct SyncConfigurationView: View {
    let selectedDocuments: [RemarkableDocument]
    let onSync: () -> Void
    
    @State private var syncDirection: SyncPair.SyncDirection = .remarkableToWorkflowy
    @State private var targetWorkflowyNode: String = ""
    @State private var createNewNode: Bool = true
    @State private var autoGenerateLinks: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            
            configurationSection
            
            previewSection
            
            Spacer()
            
            actionSection
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync Configuration")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("\(selectedDocuments.count) document\(selectedDocuments.count == 1 ? "" : "s") selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Sync Direction") {
                    Picker("Sync Direction", selection: $syncDirection) {
                        ForEach(SyncPair.SyncDirection.allCases, id: \.self) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Create new Workflowy nodes", isOn: $createNewNode)
                    
                    if !createNewNode {
                        LabeledContent("Target Node ID") {
                            TextField("Enter Workflowy node ID", text: $targetWorkflowyNode)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                Toggle("Auto-generate Dropbox links for PDFs", isOn: $autoGenerateLinks)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(selectedDocuments) { document in
                        DocumentPreviewRow(
                            document: document,
                            syncDirection: syncDirection,
                            willCreateNewNode: createNewNode,
                            willGenerateLink: autoGenerateLinks
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var actionSection: some View {
        HStack {
            Button("Cancel") {
                // Handle cancel
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Start Sync") {
                onSync()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedDocuments.isEmpty || (!createNewNode && targetWorkflowyNode.isEmpty))
        }
    }
}

struct DocumentPreviewRow: View {
    let document: RemarkableDocument
    let syncDirection: SyncPair.SyncDirection
    let willCreateNewNode: Bool
    let willGenerateLink: Bool
    
    var body: some View {
        HStack {
            Image(systemName: document.isPDF ? "doc.fill" : "note.text")
                .foregroundColor(document.isPDF ? .red : .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack {
                    syncDirectionBadge
                    
                    if willCreateNewNode {
                        Text("→ New node")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if willGenerateLink && !document.isPDF {
                        Text("PDF + Link")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            Image(systemName: "list.bullet.rectangle")
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(6)
    }
    
    private var syncDirectionBadge: some View {
        Text(syncDirection.displayName)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(syncDirection.color.opacity(0.2))
            .foregroundColor(syncDirection.color)
            .cornerRadius(4)
    }
}

extension SyncPair.SyncDirection {
    var color: Color {
        switch self {
        case .remarkableToWorkflowy:
            return .green
        case .workflowyToRemarkable:
            return .blue
        case .bidirectional:
            return .purple
        }
    }
}

#Preview {
    SyncConfigurationView(
        selectedDocuments: [
            RemarkableDocument(
                id: "1",
                name: "Meeting Notes.pdf",
                type: "pdf",
                lastModified: Date(),
                size: 1024000,
                parentId: nil
            ),
            RemarkableDocument(
                id: "2", 
                name: "Sketches.rm",
                type: "notebook",
                lastModified: Date(),
                size: 512000,
                parentId: nil
            )
        ],
        onSync: {}
    )
}