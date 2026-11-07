import SwiftUI

@main
struct EqualizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Cena de preferências para quando o usuário pressionar ⌘+, ou acionar Settings
        Settings {
            SettingsView()
        }
    }
}
