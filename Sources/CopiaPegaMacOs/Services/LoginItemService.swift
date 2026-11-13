import Foundation
import ServiceManagement

@MainActor
final class LoginItemService: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            guard !isSyncingFromService, oldValue != isEnabled else {
                return
            }
            if isEnabled {
                register()
            } else {
                unregister()
            }
        }
    }

    @Published private(set) var lastError: String?
    private var isSyncingFromService = false

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        setStateWithoutSideEffects(SMAppService.mainApp.status == .enabled)
    }

    private func setStateWithoutSideEffects(_ value: Bool) {
        isSyncingFromService = true
        isEnabled = value
        isSyncingFromService = false
    }

    private func register() {
        do {
            try SMAppService.mainApp.register()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            print("Error al registrar Login Item: \(error)")
            setStateWithoutSideEffects(SMAppService.mainApp.status == .enabled)
        }
    }

    private func unregister() {
        do {
            try SMAppService.mainApp.unregister()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            print("Error al desregistrar Login Item: \(error)")
            setStateWithoutSideEffects(SMAppService.mainApp.status == .enabled)
        }
    }
}
