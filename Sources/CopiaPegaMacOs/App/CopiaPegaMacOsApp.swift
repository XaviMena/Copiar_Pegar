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
                    guard let window else { return }

                    // Store the close callback once
                    appModel.closeHistoryWindow = {
                        appModel.isShowingHistory = false
                        window.orderOut(nil)
                    }

                    // Configure window appearance (idempotent)
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.styleMask.insert(.fullSizeContentView)
                    window.styleMask.remove(.titled)
                    window.isMovableByWindowBackground = true
                    window.backgroundColor = .clear
                    window.level = .floating

                    // Hide traffic light buttons
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true

                    if appModel.isShowingHistory {
                        // Bring the window to front
                        window.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    } else {
                        window.orderOut(nil)
                    }

                    // Install the resign-key observer only once (identified by name)
                    let observerName = "com.copiapega.resignKey"
                    if objc_getAssociatedObject(window, observerName) == nil {
                        let token = NotificationCenter.default.addObserver(
                            forName: NSWindow.didResignKeyNotification,
                            object: window,
                            queue: .main
                        ) { _ in
                            Task { @MainActor in
                                appModel.isShowingHistory = false
                                window.orderOut(nil)
                            }
                        }
                        objc_setAssociatedObject(window, observerName, token, .OBJC_ASSOCIATION_RETAIN)
                    }
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
