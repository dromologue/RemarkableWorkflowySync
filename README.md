# Remarkable Workflowy Sync

A macOS application that provides seamless synchronization between your Remarkable 2 tablet and Workflowy.

## Features

- **Document Selection**: Choose which Remarkable 2 documents to sync with Workflowy
- **Dual Tree View**: Simultaneously view Workflowy outline (3 levels deep) and Remarkable folder structure
- **Sync Direction Control**: Choose between one-way or bidirectional sync with visual picker
- **API Key Management**: Secure storage and management of API credentials with username support
- **PDF Conversion**: Automatically converts non-PDF documents to PDF format
- **Dropbox Integration**: Hosts PDFs on Dropbox in organized "Remarkable Synch" folder
- **Background Sync**: Runs continuously with customizable sync intervals
- **Menu Bar Access**: Quick access to sync status and controls from the menu bar
- **Real-time Updates**: Data refreshes automatically when settings are saved

## Setup

### Prerequisites

- macOS Sequoia (14.0) or later
- Xcode 15.0 or later
- Swift 6.2 or later

### API Keys Required

1. **Remarkable 2 Device Token**
   - Visit [remarkable.com/device/desktop/connect](https://remarkable.com/device/desktop/connect)
   - Follow the instructions to get your device token
   - Username: Your Remarkable account email (e.g., justin.arbuckle@hey.com)

2. **Workflowy API Key**
   - Generate your API key at [workflowy.com/api-key](https://workflowy.com/api-key)
   - Username: Your Workflowy account email (e.g., dromologue@gmail.com)

3. **Dropbox Access Token**
   - Create an app at [dropbox.com/developers](https://dropbox.com/developers)
   - Generate an access token for your app
   - Username: Your Dropbox account email (e.g., jdfarbuckle@gmail.com)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/dromologue/RemarkableWorkflowySync.git
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
2. Click "Settings" to configure your API keys and usernames
3. Enter your Remarkable 2 device token, Workflowy API key, and Dropbox access token
4. Add corresponding usernames/emails for each service
5. Test each connection to ensure they're working properly
6. Configure your sync preferences (interval, auto-conversion settings)

### Using the Interface

1. **Dual Tree View**: When authenticated, the sidebar simultaneously displays:
   - **Workflowy Outline**: Your complete Workflowy structure (limited to 3 levels deep for performance)
   - **Remarkable Folders**: Complete folder hierarchy with document counts
2. **Folder Selection**: Use checkboxes to select which Remarkable folders to sync
3. **Sync Direction**: Choose from the dropdown menu:
   - **Remarkable → Workflowy**: One-way sync from Remarkable to Workflowy
   - **Workflowy → Remarkable**: One-way sync from Workflowy to Remarkable
   - **Bidirectional**: Two-way sync between both platforms
4. **Document Management**: Documents are automatically organized in a "Remarkable Synch" Dropbox folder

### Syncing Documents

1. Select folders in the Remarkable folder tree
2. Choose your preferred sync direction from the dropdown
3. Click "Sync Selected" to sync specific documents or use "Sync Workflowy → Remarkable" for complete outline export
4. Monitor sync progress in the status indicator

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

1. **Authentication**: The app connects to all three services using your provided credentials and usernames
2. **Data Loading**: After authentication, both Workflowy and Remarkable data structures are loaded and displayed simultaneously
3. **Document Fetching**: The app fetches document metadata from your Remarkable 2 cloud account and folder structure
4. **Conversion**: Non-PDF documents (notebooks, sketches) are converted to PDF format using the built-in conversion service
5. **Organized Upload**: Converted PDFs are uploaded to a dedicated "Remarkable Synch" folder in your Dropbox account
6. **Workflowy Integration**: Creates or updates Workflowy nodes with document information and Dropbox links using official API v1
7. **Background Sync**: Monitors for changes and syncs automatically based on your configured schedule and selected direction

## Supported File Types

- **Remarkable Notebooks (.rm)**: Converted to PDF with stroke rendering
- **PDF Files**: Synced directly without conversion
- **EPUB Files**: Converted to PDF using WebKit rendering

## Security & Privacy

- API keys and usernames are stored securely in the macOS Keychain
- No data is transmitted to third-party servers except the official APIs (Remarkable, Workflowy v1, Dropbox v2)
- All file processing happens locally on your Mac
- Documents are organized in a dedicated "Remarkable Synch" Dropbox folder for better organization
- Usernames are used for API authentication and identification purposes only

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
