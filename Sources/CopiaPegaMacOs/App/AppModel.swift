import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var history: HistoryStore
    @Published var settingsStore: SettingsStore
    @Published var isShowingHistory = false
    @Published var isPreviewingImage = false
    @Published var loginItemService = LoginItemService()

    var openHistoryWindow: (() -> Void)?
    var closeHistoryWindow: (() -> Void)?

    private let clipboard: ClipboardService
    private let monitor: ClipboardMonitor
    private let hotKey: HotKeyService
    let pasteAutomation: PasteAutomationService
    private var cancellables = Set<AnyCancellable>()

    init() {
        let settingsStore = SettingsStore()
        let history = HistoryStore()
        let clipboard = ClipboardService()
        let hotKey = HotKeyService()
        let pasteAutomation = PasteAutomationService()

        self.history = history
        self.settingsStore = settingsStore
        self.clipboard = clipboard
        self.hotKey = hotKey
        self.pasteAutomation = pasteAutomation
        self.monitor = ClipboardMonitor(clipboard: clipboard, history: history, settingsStore: settingsStore)

        hotKey.onPressed = { [weak self] in
            self?.showHistory()
        }
        hotKey.register(settings: settingsStore.settings)
        monitor.start()

        history.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        settingsStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] settings in
                Task { @MainActor in
                    self?.history.prune(settings: settings)
                    self?.hotKey.register(settings: settings)
                }
            }
            .store(in: &cancellables)
    }

    func restore(_ entry: ClipboardEntry) {
        clipboard.restore(entry, history: history)
    }

    func restoreAndPaste(_ entry: ClipboardEntry) {
        // 1. Put the selected entry on the system clipboard
        restore(entry)
        // 2. Close our window (this hides it via orderOut)
        closeHistoryWindow?()
        // 3. Activate the previously-frontmost app and send Cmd+V
        pasteAutomation.pasteIntoLastTarget()
    }

    func togglePin(_ entry: ClipboardEntry) {
        history.togglePin(entry)
    }

    func delete(_ entry: ClipboardEntry) {
        history.delete(entry)
    }

    func clearHistory() {
        history.clear()
    }

    func showHistory() {
        // Capture the currently frontmost app BEFORE we show our window
        pasteAutomation.captureCurrentTarget()
        isShowingHistory = true
        NSApp.activate(ignoringOtherApps: true)
        openHistoryWindow?()
    }
}
