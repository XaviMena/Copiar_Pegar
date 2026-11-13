import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class HistoryViewState: ObservableObject {
    @Published var selection: ClipboardEntry.ID?
    @Published var searchText = ""
    @Published var showSearch = false
    @Published var isSearchFocused = false
    @Published var previewedImageEntry: ClipboardEntry?
    @Published var openingImageEntryID: ClipboardEntry.ID?
    @Published var hoveredEntryID: ClipboardEntry.ID?
    @Published var previewImage: NSImage?
    @Published var isPreviewLoading = true
}

@MainActor
final class AppModel: ObservableObject {
    @Published var history: HistoryStore
    @Published var settingsStore: SettingsStore
    @Published var isShowingHistory = false
    @Published var isPreviewingImage = false
    @Published var isAccessibilityTrusted = false
    @Published var loginItemService = LoginItemService()
    @Published var hotKey: HotKeyService
    let historyViewState = HistoryViewState()

    private let clipboard: ClipboardService
    private let monitor: ClipboardMonitor
    let pasteAutomation: PasteAutomationService
    private var historyWindow: KeyableWindow?
    private var windowObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        let settingsStore = SettingsStore()
        let history = HistoryStore()
        let clipboard = ClipboardService()
        let hotKey = HotKeyService()
        let pasteAutomation = PasteAutomationService()

        history.prune(settings: settingsStore.settings)

        self.history = history
        self.settingsStore = settingsStore
        self.clipboard = clipboard
        self.hotKey = hotKey
        self.pasteAutomation = pasteAutomation
        self.isAccessibilityTrusted = pasteAutomation.isAccessibilityTrusted
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

        hotKey.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        loginItemService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        historyViewState.objectWillChange
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

    private func ensureHistoryWindow() -> KeyableWindow {
        if let historyWindow {
            return historyWindow
        }

        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let rootView = HistoryWindowView()
            .environmentObject(self)
            .frame(width: 380, height: 500)
        window.contentView = NSHostingView(rootView: rootView)
        let autosaveName = NSWindow.FrameAutosaveName("CopiaPegaHistoryWindowFrame")
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setContentSize(NSSize(width: 380, height: 500))
        window.setFrameAutosaveName(autosaveName)

        let resignKeyToken = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isShowingHistory, !self.isPreviewingImage else { return }
                self.closeHistory()
            }
        }

        let resignActiveToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isShowingHistory, !self.isPreviewingImage else { return }
                self.closeHistory()
            }
        }

        windowObservers = [resignKeyToken, resignActiveToken]
        historyWindow = window
        return window
    }

    func restore(_ entry: ClipboardEntry) {
        clipboard.restore(entry, history: history)
    }

    func restoreAndPaste(_ entry: ClipboardEntry) {
        restore(entry)
        closeHistory()
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
        pasteAutomation.captureCurrentTarget()
        history.prune(settings: settingsStore.settings)
        let window = ensureHistoryWindow()
        isShowingHistory = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func closeHistory() {
        isShowingHistory = false
        historyWindow?.orderOut(nil)
    }

    func refreshSystemStatus() {
        isAccessibilityTrusted = pasteAutomation.isAccessibilityTrusted
        loginItemService.refresh()
    }
}
