import SwiftUI

@main
struct CopiaPegaMacOsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appModel)
        } label: {
            Image(systemName: "list.clipboard")
                .onAppear {
                    appModel.openHistoryWindow = {
                        openWindow(id: "history")
                    }
                }
        }
        .menuBarExtraStyle(.menu)

        Window("Historial de portapapeles", id: "history") {
            HistoryWindowView()
                .environmentObject(appModel)
                .background(WindowAccessor { window in
                    appModel.attachHistoryWindow(window)
                })
                .frame(width: 380, height: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(width: 420)
        }
    }
}
