import AppKit
import ApplicationServices
import Foundation

@MainActor
final class PasteAutomationService {
    private var lastTargetBundleIdentifier: String?
    private var lastTargetPID: pid_t?
    private var observer: NSObjectProtocol?
    private var pendingPasteTask: Task<Void, Never>?

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    init(workspace: NSWorkspace = .shared) {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier

        if let frontmost = workspace.frontmostApplication,
           frontmost.bundleIdentifier != ownBundleIdentifier {
            lastTargetBundleIdentifier = frontmost.bundleIdentifier
            lastTargetPID = frontmost.processIdentifier
        }

        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != ownBundleIdentifier else {
                return
            }

            let bundleIdentifier = app.bundleIdentifier
            let processIdentifier = app.processIdentifier
            Task { @MainActor in
                self?.lastTargetBundleIdentifier = bundleIdentifier
                self?.lastTargetPID = processIdentifier
            }
        }
    }

    /// Captures the currently frontmost app before our window takes focus.
    /// Call this right before showing the clipboard history window.
    func captureCurrentTarget(workspace: NSWorkspace = .shared) {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        if let frontmost = workspace.frontmostApplication,
           frontmost.bundleIdentifier != ownBundleIdentifier {
            lastTargetBundleIdentifier = frontmost.bundleIdentifier
            lastTargetPID = frontmost.processIdentifier
        }
    }

    func pasteIntoLastTarget() {
        guard ensureAccessibilityPermission() else {
            return
        }

        let targetPID = activateLastTarget()
        pendingPasteTask?.cancel()
        pendingPasteTask = Task { @MainActor in
            if let targetPID {
                for _ in 0..<20 {
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID {
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(25))
                    if Task.isCancelled { return }
                }
            } else {
                try? await Task.sleep(for: .milliseconds(150))
            }

            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            Self.sendCommandV()
        }
    }

    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        ensureAccessibilityPermission()
    }

    @discardableResult
    private func activateLastTarget() -> pid_t? {
        // Try by PID first (more reliable), then fall back to bundle identifier
        if let pid = lastTargetPID,
           let app = NSRunningApplication(processIdentifier: pid),
           app.isTerminated == false {
            app.activate()
            return pid
        }

        guard let bundleId = lastTargetBundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
            return nil
        }

        app.activate()
        return app.processIdentifier
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [
            promptKey: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return false
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeForV: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
