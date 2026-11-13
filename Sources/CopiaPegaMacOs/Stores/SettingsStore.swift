import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedClickCount = defaults.object(forKey: Keys.pasteClickCount) as? Int ?? AppSettings.defaults.pasteClickCount
        let validClickCount = (storedClickCount == 1 || storedClickCount == 2) ? storedClickCount : AppSettings.defaults.pasteClickCount

        self.settings = AppSettings(
            maxItems: defaults.object(forKey: Keys.maxItems) as? Int ?? AppSettings.defaults.maxItems,
            retentionHours: defaults.object(forKey: Keys.retentionHours) as? Int ?? AppSettings.defaults.retentionHours,
            saveImages: defaults.object(forKey: Keys.saveImages) as? Bool ?? AppSettings.defaults.saveImages,
            pasteClickCount: validClickCount,
            hotKeyKeyCode: UInt32(defaults.object(forKey: Keys.hotKeyKeyCode) as? Int ?? Int(AppSettings.defaults.hotKeyKeyCode)),
            hotKeyModifiers: UInt32(defaults.object(forKey: Keys.hotKeyModifiers) as? Int ?? Int(AppSettings.defaults.hotKeyModifiers))
        )
    }

    func reset() {
        settings = .defaults
    }

    private func save() {
        defaults.set(settings.maxItems, forKey: Keys.maxItems)
        defaults.set(settings.retentionHours, forKey: Keys.retentionHours)
        defaults.set(settings.saveImages, forKey: Keys.saveImages)
        defaults.set(settings.pasteClickCount, forKey: Keys.pasteClickCount)
        defaults.set(Int(settings.hotKeyKeyCode), forKey: Keys.hotKeyKeyCode)
        defaults.set(Int(settings.hotKeyModifiers), forKey: Keys.hotKeyModifiers)
    }

    private enum Keys {
        static let maxItems = "settings.maxItems"
        static let retentionHours = "settings.retentionHours"
        static let saveImages = "settings.saveImages"
        static let pasteClickCount = "settings.pasteClickCount"
        static let hotKeyKeyCode = "settings.hotKeyKeyCode"
        static let hotKeyModifiers = "settings.hotKeyModifiers"
    }
}
