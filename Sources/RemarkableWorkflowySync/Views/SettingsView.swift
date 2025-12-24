import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var onSave: (() -> Void)?
    var isFirstTimeSetup: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text(isFirstTimeSetup ? "Welcome to Remarkable-Workflowy Sync" : "Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Save") {
                    settings.saveSettings()
                    onSave?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separatorColor)),
                alignment: .bottom
            )
            
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    if isFirstTimeSetup {
                        welcomeSection
                    }
                    
                    // Show auto-load status if tokens were loaded from file
                    if settings.autoLoadedFromFile {
                        autoLoadStatusSection
                    }
                    
                    apiKeysSection
                    
                    // Side-by-side layout for sync settings and about
                    HStack(alignment: .top, spacing: 24) {
                        syncSettingsSection
                            .frame(maxWidth: .infinity)
                        
                        aboutSection
                            .frame(maxWidth: .infinity)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 700, height: 600)
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Welcome!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("To get started, please enter your API credentials below. You'll need accounts for both Remarkable 2 and Workflowy to sync your documents.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Text("Dropbox is optional but recommended for PDF hosting and sharing.")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var autoLoadStatusSection: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("API Tokens Auto-Loaded")
                    .font(.headline)
                    .foregroundColor(.green)
                Text("Credentials were automatically loaded from api-tokens.md file")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Show connection status summary
            HStack(spacing: 8) {
                if settings.remarkableConnectionStatus == .connected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                if settings.workflowyConnectionStatus == .connected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                if !settings.dropboxAccessToken.isEmpty && settings.dropboxConnectionStatus == .connected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            Text("API Keys")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Top row: Required APIs
            HStack(alignment: .top, spacing: 16) {
                // Remarkable Authentication
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Remarkable Authentication")
                            .font(.headline)
                        Spacer()
                        if !settings.remarkableDeviceToken.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                    
                    // Username field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username/Email")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("justin.arbuckle@hey.com", text: $settings.remarkableUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 32)
                    }
                    
                    // Show registration workflow
                    if settings.remarkableDeviceToken.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // Registration code input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Step 1: Enter Registration Code")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                
                                HStack {
                                    TextField("8-character code", text: $settings.remarkableRegistrationCode)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(height: 40)
                                        .onChange(of: settings.remarkableRegistrationCode) { newValue in
                                            // Limit to 8 characters and uppercase
                                            settings.remarkableRegistrationCode = String(newValue.uppercased().prefix(8))
                                        }
                                    
                                    Button("Register Device") {
                                        Task {
                                            await settings.registerRemarkableDevice()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(settings.remarkableRegistrationCode.count != 8 || settings.isTestingConnection)
                                }
                            }
                            
                            if !settings.remarkableRegistrationCode.isEmpty {
                                Text("Step 2: Click 'Register Device' to exchange your code for an access token")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // Show authenticated status
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Device Registered & Authenticated")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Bearer Token: ****\(settings.remarkableDeviceToken.suffix(8))")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Re-authenticate") {
                                    settings.remarkableDeviceToken = ""
                                    settings.remarkableRegistrationCode = ""
                                    settings.remarkableConnectionStatus = .unknown
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("How to get your registration code:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("1. Visit: my.remarkable.com/device/desktop/connect")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                        
                        Text("2. Copy the 8-character code and enter it above")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                        
                        Text("3. The app will exchange it for a permanent access token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    }
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(10)
                .frame(maxWidth: .infinity)
                
                // Workflowy API Key
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Workflowy API Key")
                            .font(.headline)
                        Spacer()
                        if !settings.workflowyApiKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                    
                    // Username field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username/Email")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("dromologue@gmail.com", text: $settings.workflowyUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 32)
                    }
                    
                    SecureField("Enter your API key", text: $settings.workflowyApiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 40)
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Generate your API key at workflowy.com/api-key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(10)
                .frame(maxWidth: .infinity)
            }
            
            // Bottom row: Optional API
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Dropbox Access Token")
                        .font(.headline)
                    Text("(Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !settings.dropboxAccessToken.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
                
                // Username field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Username/Email")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField("jdfarbuckle@gmail.com", text: $settings.dropboxUsername)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 32)
                }
                
                SecureField("Enter your access token", text: $settings.dropboxAccessToken)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 40)
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Create an app at dropbox.com/developers to get your access token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            Text("Sync Settings")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Background Sync Toggle
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Background Sync")
                                .font(.headline)
                            Text("Automatically sync documents on schedule")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.enableBackgroundSync)
                    }
                    
                    if settings.enableBackgroundSync {
                        // Sync Interval
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sync Interval")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(formatInterval(settings.syncInterval))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { settings.syncInterval / 60 },
                                    set: { settings.syncInterval = $0 * 60 }
                                ),
                                in: 5...240,
                                step: 5
                            ) {
                                Text("Sync Interval")
                            }
                        }
                    }
                }
                
                Divider()
                
                // Auto-convert Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-convert to PDF")
                            .font(.headline)
                        Text("Convert notebook files to PDF format")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.autoConvertToPDF)
                }
            }
            .padding(16)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
            
            // Connection Tests
            VStack(alignment: .leading, spacing: 16) {
                Text("Connection Tests")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    // Remarkable Test
                    HStack {
                        Button("Test Remarkable Connection") {
                            Task {
                                await settings.testRemarkableConnection()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(settings.remarkableDeviceToken.isEmpty || settings.isTestingConnection)
                        
                        if settings.isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                        
                        connectionStatusIndicator(settings.remarkableConnectionStatus)
                    }
                    
                    // Workflowy Test
                    HStack {
                        Button("Test Workflowy Connection") {
                            Task {
                                await settings.testWorkflowyConnection()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(settings.workflowyApiKey.isEmpty || settings.isTestingConnection)
                        
                        if settings.isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                        
                        connectionStatusIndicator(settings.workflowyConnectionStatus)
                    }
                    
                    // Dropbox Test (if token exists)
                    if !settings.dropboxAccessToken.isEmpty {
                        HStack {
                            Button("Test Dropbox Connection") {
                                Task {
                                    await settings.testDropboxConnection()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(settings.isTestingConnection)
                            
                            if settings.isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            
                            Spacer()
                            
                            connectionStatusIndicator(settings.dropboxConnectionStatus)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("About")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Version")
                        .font(.subheadline)
                    Spacer()
                    Text("1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Last Sync")
                        .font(.subheadline)
                    Spacer()
                    Text(settings.lastSyncDate?.formatted() ?? "Never")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    Link("GitHub Repository", destination: URL(string: "https://github.com/your-repo")!)
                        .font(.subheadline)
                    
                    Link("Support", destination: URL(string: "mailto:support@yourapp.com")!)
                        .font(.subheadline)
                }
            }
            .padding(16)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    private func connectionStatusIndicator(_ status: ConnectionStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
            
            Text(status.displayText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func formatInterval(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
}

enum ConnectionStatus: Equatable {
    case unknown
    case connected
    case failed(String)
    
    var color: Color {
        switch self {
        case .unknown:
            return .secondary
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
    
    var displayText: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .connected:
            return "Connected"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}

#Preview {
    SettingsView()
}