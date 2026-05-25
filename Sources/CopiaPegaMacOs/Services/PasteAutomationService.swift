import AppKit
import ApplicationServices
import Foundation

@MainActor
final class PasteAutomationService {
    private var lastTargetBundleIdentifier: String?
    private var lastTargetPID: pid_t?
    private var observer: NSObjectProtocol?

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

            Task { @MainActor in
                self?.lastTargetBundleIdentifier = app.bundleIdentifier
                self?.lastTargetPID = app.processIdentifier
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

        activateLastTarget()

        // Give more time for the target app to fully activate before pasting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Self.sendCommandV()
        }
    }

    private func activateLastTarget() {
        // Try by PID first (more reliable), then fall back to bundle identifier
        if let pid = lastTargetPID,
           let app = NSRunningApplication(processIdentifier: pid),
           app.isTerminated == false {
            app.activate()
            return
        }

        guard let bundleId = lastTargetBundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
            return
        }

        app.activate()
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = [
            "AXTrustedCheckOptionPrompt": true
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
