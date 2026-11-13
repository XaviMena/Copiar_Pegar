import AppKit
import Carbon
import Foundation

@MainActor
final class HotKeyService: ObservableObject {
    @Published private(set) var registrationFailed = false
    var onPressed: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    func register(settings: AppSettings) {
        unregisterHotKeys()
        installHandlerIfNeeded()

        registrationFailed = !registerHotKey(
            keyCode: settings.hotKeyKeyCode,
            modifiers: settings.hotKeyModifiers,
            id: 1
        )
    }

    func unregister() {
        unregisterHotKeys()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if hotKeyID.signature == OSType(UInt32.fromFourCharCode("CPGV")) {
                    Task { @MainActor in
                        service.onPressed?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
    }

    @discardableResult
    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) -> Bool {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(UInt32.fromFourCharCode("CPGV")), id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs.append(hotKeyRef)
            return true
        }
        return false
    }

    private func unregisterHotKeys() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
    }
}

private extension UInt32 {
    static func fromFourCharCode(_ string: String) -> UInt32 {
        string.utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
