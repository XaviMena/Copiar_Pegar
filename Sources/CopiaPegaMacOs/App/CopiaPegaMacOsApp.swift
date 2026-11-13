import SwiftUI

@main
struct CopiaPegaMacOsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private static let sharedAppModel = AppModel()
    private var appModel: AppModel { Self.sharedAppModel }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appModel)
        } label: {
            Image(systemName: "list.clipboard")
        }
        .menuBarExtraStyle(.menu)
    }
}
