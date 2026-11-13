import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
private final class KeyableWindow: NSWindow {
    var handleKeyEvent: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleKeyEvent?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleKeyEvent?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
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
    private var settingsWindow: NSWindow?
    private var windowObservers: [NSObjectProtocol] = []
    private var settingsCloseObserver: NSObjectProtocol?
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
        window.handleKeyEvent = { [weak self] event in
            self?.handleHistoryKeyEvent(event) ?? false
        }

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

    var filteredHistoryEntries: [ClipboardEntry] {
        let query = historyViewState.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return history.entries }

        return history.entries.filter { entry in
            if entry.kind == .text, let text = entry.text {
                return text.lowercased().contains(query)
            }
            return entry.title.lowercased().contains(query)
        }
    }

    var selectedHistoryEntry: ClipboardEntry? {
        let entries = filteredHistoryEntries
        if let selection = historyViewState.selection,
           let match = entries.first(where: { $0.id == selection }) {
            return match
        }
        return entries.first
    }

    func moveHistorySelection(by delta: Int) {
        let entries = filteredHistoryEntries
        guard !entries.isEmpty else { return }

        guard let currentID = historyViewState.selection,
              let currentIndex = entries.firstIndex(where: { $0.id == currentID }) else {
            historyViewState.selection = entries.first?.id
            return
        }

        let nextIndex = max(0, min(entries.count - 1, currentIndex + delta))
        historyViewState.selection = entries[nextIndex].id
    }

    func pasteSelectedHistoryEntry() {
        guard let entry = selectedHistoryEntry else { return }
        restoreAndPaste(entry)
    }

    func deleteSelectedHistoryEntry() {
        guard let entry = selectedHistoryEntry else { return }
        let entries = filteredHistoryEntries
        let nextSelection: ClipboardEntry.ID?
        if let currentIndex = entries.firstIndex(where: { $0.id == entry.id }) {
            if currentIndex + 1 < entries.count {
                nextSelection = entries[currentIndex + 1].id
            } else if currentIndex > 0 {
                nextSelection = entries[currentIndex - 1].id
            } else {
                nextSelection = nil
            }
        } else {
            nextSelection = nil
        }

        delete(entry)
        historyViewState.selection = nextSelection
        ensureVisibleHistorySelection()
    }

    func ensureVisibleHistorySelection() {
        let entries = filteredHistoryEntries
        if let selection = historyViewState.selection,
           entries.contains(where: { $0.id == selection }) {
            return
        }
        historyViewState.selection = entries.first?.id
    }

    func toggleHistorySearch() {
        historyViewState.showSearch.toggle()
        if !historyViewState.showSearch {
            historyViewState.isSearchFocused = false
            historyViewState.searchText = ""
            historyWindow?.makeFirstResponder(nil)
            ensureVisibleHistorySelection()
        }
    }

    func resetHistoryPresentation() {
        historyViewState.showSearch = false
        historyViewState.isSearchFocused = false
        historyViewState.searchText = ""
        historyViewState.hoveredEntryID = nil
        historyViewState.selection = history.entries.first?.id
        historyWindow?.makeFirstResponder(nil)
    }

    private func handleHistoryKeyEvent(_ event: NSEvent) -> Bool {
        guard isShowingHistory, !isPreviewingImage else {
            return false
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let primaryModifiers = modifiers.intersection([.command, .control, .option])
        let key = event.charactersIgnoringModifiers?.lowercased()

        if modifiers == .command, key == "f" {
            toggleHistorySearch()
            return true
        }

        guard primaryModifiers.isEmpty else {
            return false
        }

        if event.keyCode == 53 { // Esc
            closeHistory()
            return true
        }

        if historyWindow?.firstResponder is NSTextView {
            return false
        }

        switch event.keyCode {
        case 126: // Up arrow
            moveHistorySelection(by: -1)
            return true
        case 125: // Down arrow
            moveHistorySelection(by: 1)
            return true
        case 36, 76: // Return / Keypad Enter
            pasteSelectedHistoryEntry()
            return true
        case 51, 117: // Backspace / Forward Delete
            deleteSelectedHistoryEntry()
            return true
        default:
            return false
        }
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
        resetHistoryPresentation()
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

    private func ensureSettingsWindow() -> NSWindow {
        if let settingsWindow {
            return settingsWindow
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 590),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ajustes"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 500)

        let rootView = SettingsView()
            .environmentObject(self)
            .frame(minWidth: 420, idealWidth: 450, minHeight: 500, idealHeight: 590)
        window.contentView = NSHostingView(rootView: rootView)

        let autosaveName = NSWindow.FrameAutosaveName("CopiaPegaSettingsWindowFrame")
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(autosaveName)

        settingsCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                NSApp.setActivationPolicy(.accessory)
            }
        }

        settingsWindow = window
        return window
    }

    func showSettings() {
        closeHistory()
        refreshSystemStatus()
        let window = ensureSettingsWindow()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        Task { @MainActor [weak window] in
            try? await Task.sleep(for: .milliseconds(80))
            guard let window, window.isVisible else { return }
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
