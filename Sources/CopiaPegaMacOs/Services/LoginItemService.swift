import Foundation
import ServiceManagement

@MainActor
final class LoginItemService: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            if isEnabled {
                register()
            } else {
                unregister()
            }
        }
    }

    init() {
        // Check the current registration status
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func register() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Error al registrar Login Item: \(error)")
            // Revert the toggle if registration fails
            isEnabled = false
        }
    }

    private func unregister() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("Error al desregistrar Login Item: \(error)")
            // Revert the toggle if unregistration fails
            isEnabled = true
        }
    }
}
