import SwiftUI

@main
struct MainApp: SwiftUI.App {
    @StateObject private var buddy = Buddy.shared

    init() {
        MainActor.assumeIsolated { BuddyPanel.shared.show() }
    }

    var body: some SwiftUI.Scene {
        LampMenuBar(menu: "Paperclip", systemImage: "paperclip") {
            BuddyMenu(buddy: buddy)
        }
        .commands { LampCommands() }

        Settings {
            SettingsView()
        }
    }
}

/// The menu bar icon's menu.
struct BuddyMenu: View {
    @ObservedObject var buddy: Buddy

    var body: some View {
        Button("Give Me a Tip Now") { buddy.tipNow() }
            .keyboardShortcut("t")
        Button("Ask a Question…") { buddy.openAsk() }
            .keyboardShortcut("k")
        Divider()
        Toggle("Show Paperclip", isOn: $buddy.isShown)
        Toggle("Quiet for an Hour", isOn: Binding(get: { buddy.isQuiet }, set: { buddy.setQuiet($0) }))
        Button("Move Back to the Corner") { BuddyPanel.shared.moveToCorner() }
    }
}
