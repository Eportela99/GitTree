import SwiftUI

@main
struct GitTreeApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .frame(minWidth: 960, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Repository") {
                Button("Open Folder...") {
                    appViewModel.showFolderPicker = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Initialize Repository") {
                    appViewModel.showInitRepoSheet = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Fetch") {
                    Task { await appViewModel.fetch() }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Pull") {
                    Task { await appViewModel.pull() }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Push") {
                    Task { await appViewModel.push() }
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }
    }
}
