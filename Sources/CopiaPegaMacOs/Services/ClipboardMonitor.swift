import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    private let clipboard: ClipboardService
    private let history: HistoryStore
    private let settingsStore: SettingsStore
    private var timer: Timer?
    private var lastChangeCount: Int

    init(clipboard: ClipboardService, history: HistoryStore, settingsStore: SettingsStore) {
        self.clipboard = clipboard
        self.history = history
        self.settingsStore = settingsStore
        self.lastChangeCount = clipboard.changeCount
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        let current = clipboard.changeCount
        guard current != lastChangeCount else {
            return
        }
        lastChangeCount = current

        guard !clipboard.shouldIgnore(changeCount: current),
              let payload = clipboard.readCurrent(saveImages: settingsStore.settings.saveImages) else {
            return
        }

        switch payload {
        case let .text(value, hash):
            history.addText(value, hash: hash, settings: settingsStore.settings)
        case let .image(image, data, hash):
            history.addImage(image, data: data, hash: hash, settings: settingsStore.settings)
        }
    }
}
