# Remarkable Workflowy Sync

A macOS application that provides seamless synchronization between your Remarkable 2 tablet and Workflowy.

## Features

- **Document Selection**: Choose which Remarkable 2 documents to sync with Workflowy
- **API Key Management**: Secure storage and management of API credentials
- **PDF Conversion**: Automatically converts non-PDF documents to PDF format
- **Dropbox Integration**: Hosts PDFs on Dropbox and provides shareable links
- **Background Sync**: Runs continuously with customizable sync intervals
- **Menu Bar Access**: Quick access to sync status and controls from the menu bar

## Setup

### Prerequisites

- macOS Sequoia (14.0) or later
- Xcode 15.0 or later
- Swift 6.2 or later

### API Keys Required

1. **Remarkable 2 Device Token**
   - Visit [remarkable.com/device/desktop/connect](https://remarkable.com/device/desktop/connect)
   - Follow the instructions to get your device token

2. **Workflowy API Key**
   - Generate your API key at [workflowy.com/api-key](https://workflowy.com/api-key)

3. **Dropbox Access Token**
   - Create an app at [dropbox.com/developers](https://dropbox.com/developers)
   - Generate an access token for your app

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd RemarkableWorkflowySync
   ```

2. Build the project:
   ```bash
   swift build
   ```

3. Run the application:
   ```bash
   swift run
   ```

## Usage

### First Launch

1. Launch the application
2. Click "Settings" to configure your API keys
3. Enter your Remarkable 2 device token, Workflowy API key, and Dropbox access token
4. Test each connection to ensure they're working properly
5. Configure your sync preferences (interval, auto-conversion settings)

### Syncing Documents

1. The main interface shows all your Remarkable 2 documents
2. Select the documents you want to sync with Workflowy
3. Configure sync direction in the detail panel:
   - **Remarkable → Workflowy**: One-way sync from Remarkable to Workflowy
   - **Workflowy → Remarkable**: One-way sync from Workflowy to Remarkable (limited support)
   - **Bidirectional**: Two-way sync (experimental)
4. Click "Start Sync" to begin synchronization

### Background Sync

- Enable "Background Sync" in settings to automatically sync at regular intervals
- The app will continue syncing even when minimized
- Access quick controls from the menu bar icon

## Architecture

```
Sources/RemarkableWorkflowySync/
├── Models/
│   └── AppModels.swift          # Data models and app settings
├── Views/
│   ├── MainView.swift           # Main application interface
│   ├── SettingsView.swift       # Settings configuration
│   └── SyncConfigurationView.swift # Sync setup interface
├── Services/
│   ├── RemarkableService.swift  # Remarkable 2 API integration
│   ├── WorkflowyService.swift   # Workflowy API integration
│   ├── DropboxService.swift     # Dropbox file hosting
│   ├── PDFConversionService.swift # Document to PDF conversion
│   └── SyncService.swift        # Background sync coordination
├── Utils/
│   └── ViewModels.swift         # View model classes
└── RemarkableWorkflowySync.swift # App entry point
```

## How It Works

1. **Document Fetching**: The app connects to your Remarkable 2 cloud account to fetch document metadata and content
2. **Conversion**: Non-PDF documents (notebooks, sketches) are converted to PDF format using the built-in conversion service
3. **Upload**: Converted PDFs are uploaded to your Dropbox account for hosting
4. **Workflowy Integration**: Creates or updates Workflowy nodes with document information and Dropbox links
5. **Background Sync**: Monitors for changes and syncs automatically based on your configured schedule

## Supported File Types

- **Remarkable Notebooks (.rm)**: Converted to PDF with stroke rendering
- **PDF Files**: Synced directly without conversion
- **EPUB Files**: Converted to PDF using WebKit rendering

## Security & Privacy

- API keys are stored securely in the macOS Keychain
- No data is transmitted to third-party servers except the official APIs
- All file processing happens locally on your Mac
- Dropbox hosting respects your account's privacy settings

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify your API keys are correct
   - Check your internet connection
   - Ensure your Remarkable 2 device is connected

2. **Sync Issues**
   - Check API rate limits for Workflowy
   - Verify Dropbox storage space
   - Review sync logs in the application

3. **PDF Conversion Problems**
   - Ensure sufficient disk space for temporary files
   - Check file permissions in the application directory

### Support

For bug reports and feature requests, please visit our GitHub repository or contact support.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

---

**Note**: This application is not officially affiliated with reMarkable AS or Workflowy. Use at your own risk and ensure you comply with the terms of service of all connected platforms.