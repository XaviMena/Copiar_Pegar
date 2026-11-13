import Foundation

enum PasteClickMode: Int, CaseIterable, Identifiable {
    case single = 1
    case double = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .single:
            return "1 clic"
        case .double:
            return "2 clics"
        }
    }
}

struct AppSettings: Equatable {
    var maxItems: Int
    var retentionHours: Int
    var saveImages: Bool
    var pasteClickCount: Int
    var hotKeyKeyCode: UInt32
    var hotKeyModifiers: UInt32

    static let defaults = AppSettings(
        maxItems: 50,
        retentionHours: 24,
        saveImages: true,
        pasteClickCount: PasteClickMode.double.rawValue,
        hotKeyKeyCode: HotKeyDefaults.keyV,
        hotKeyModifiers: HotKeyDefaults.commandOption
    )
}

enum HotKeyDefaults {
    static let keyV: UInt32 = 9
    static let keyC: UInt32 = 8
    static let keyH: UInt32 = 4
    static let commandOption: UInt32 = 2_304
    static let controlOption: UInt32 = 6_144
    static let controlCommand: UInt32 = 4_352 // controlKey (4096) + cmdKey (256)
}

struct HotKeyChoice: Identifiable, Equatable {
    let id: UInt32
    let name: String
    let keyCode: UInt32
}

struct HotKeyModifierChoice: Identifiable, Equatable {
    let id: UInt32
    let name: String
    let modifiers: UInt32
}

enum HotKeyChoices {
    static let keys = [
        HotKeyChoice(id: HotKeyDefaults.keyV, name: "V", keyCode: HotKeyDefaults.keyV),
        HotKeyChoice(id: HotKeyDefaults.keyC, name: "C", keyCode: HotKeyDefaults.keyC),
        HotKeyChoice(id: HotKeyDefaults.keyH, name: "H", keyCode: HotKeyDefaults.keyH)
    ]

    static let modifiers = [
        HotKeyModifierChoice(id: HotKeyDefaults.commandOption, name: "Option + Command", modifiers: HotKeyDefaults.commandOption),
        HotKeyModifierChoice(id: HotKeyDefaults.controlOption, name: "Control + Option", modifiers: HotKeyDefaults.controlOption),
        HotKeyModifierChoice(id: HotKeyDefaults.controlCommand, name: "Control + Command", modifiers: HotKeyDefaults.controlCommand)
    ]
}
