import SwiftUI
import AppKit

@main
struct RemarkableWorkflowySyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var menuBarManager = MenuBarManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Remarkable Workflowy Sync") {
                    showAboutPanel()
                }
            }
            
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    showPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
    
    private func showAboutPanel() {
        let aboutPanel = NSAlert()
        aboutPanel.messageText = "Remarkable Workflowy Sync"
        aboutPanel.informativeText = """
        Version 1.0.0
        
        Sync your Remarkable 2 documents with Workflowy seamlessly.
        
        Features:
        • Document selection and sync management
        • Automatic PDF conversion
        • Dropbox integration for file hosting
        • Background sync with customizable intervals
        • Menu bar access for quick actions
        
        © 2024 Your Company
        """
        aboutPanel.alertStyle = .informational
        aboutPanel.runModal()
    }
    
    private func showPreferences() {
        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        preferencesWindow.title = "Preferences"
        preferencesWindow.contentView = NSHostingView(rootView: SettingsView())
        preferencesWindow.center()
        preferencesWindow.makeKeyAndOrderFront(nil)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            setupAppearance()
            
            if let window = NSApp.windows.first {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    @MainActor
    private func setupAppearance() {
        if #available(macOS 11.0, *) {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
}
