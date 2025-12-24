# 🚀 How to Run the Remarkable-Workflowy Sync App

## **Method 1: Xcode (Recommended for macOS GUI App)**

1. **Open in Xcode:**
   ```bash
   open Package.swift
   ```
   This will open the project in Xcode.

2. **Set the Scheme:**
   - In Xcode, select the "RemarkableWorkflowySync" scheme
   - Make sure "My Mac" is selected as the destination

3. **Run the App:**
   - Press `Cmd + R` or click the Play button
   - The app will build and launch with its GUI interface

## **Method 2: Command Line (Development/Testing)**

```bash
cd /Users/dromologue/code/RemarkableWorkflowySync

# Option A: Direct run
swift run

# Option B: Build then run
swift build
./.build/debug/RemarkableWorkflowySync
```

## **Method 3: Create a Standalone App Bundle**

For a proper macOS app experience, you can build it as an app bundle:

1. **Create App Structure:**
   ```bash
   mkdir -p "RemarkableWorkflowySync.app/Contents/MacOS"
   mkdir -p "RemarkableWorkflowySync.app/Contents/Resources"
   ```

2. **Copy Executable:**
   ```bash
   swift build --configuration release
   cp .build/release/RemarkableWorkflowySync "RemarkableWorkflowySync.app/Contents/MacOS/"
   ```

3. **Create Info.plist:**
   ```bash
   cp Info.plist "RemarkableWorkflowySync.app/Contents/"
   ```

4. **Launch App:**
   ```bash
   open RemarkableWorkflowySync.app
   ```

## **🔧 Before First Run**

The app needs API credentials to function. When you first run it:

1. **Click "Settings" in the toolbar**
2. **Enter your API keys:**
   - **Remarkable 2 Device Token**: Get from [remarkable.com/device/desktop/connect](https://remarkable.com/device/desktop/connect)
   - **Workflowy API Key**: Generate at [workflowy.com/api-key](https://workflowy.com/api-key)
   - **Dropbox Access Token**: Create app at [dropbox.com/developers](https://dropbox.com/developers)

3. **Test connections** using the built-in test buttons
4. **Configure sync preferences** (interval, auto-convert, etc.)

## **🎯 Expected Behavior**

When running successfully, you should see:

- **Main Window**: Split view with document list and sync configuration
- **Menu Bar Icon**: Quick access to sync status and controls
- **Settings Window**: API key management and preferences
- **Document Selection**: List of Remarkable 2 documents with file types
- **Sync Controls**: Direction selection and sync initiation

## **📋 System Requirements**

- **macOS Sequoia (14.0+)**
- **Xcode 15.0+** (if using Xcode method)
- **Swift 6.2+**
- **Internet connection** for API access

## **🐛 Troubleshooting**

If the app doesn't start:

1. **Check Build:** `swift build` should complete without errors
2. **Check Tests:** `swift test` should pass all 32 tests
3. **Check Permissions:** The app may need network access permissions
4. **Check Console:** Look for error messages in Console.app

## **🔍 Development Mode**

For development and debugging:

```bash
# Run with verbose output
swift run --verbose

# Build in debug mode (default)
swift build --configuration debug

# Clean and rebuild
swift package clean
swift build
```

The **Xcode method is recommended** for the full macOS GUI experience with proper window management, menu bar integration, and native app behavior.