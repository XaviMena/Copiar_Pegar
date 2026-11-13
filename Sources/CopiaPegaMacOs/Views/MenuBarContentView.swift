import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel

    private var openHistoryShortcut: (key: KeyEquivalent, modifiers: EventModifiers) {
        let settings = appModel.settingsStore.settings
        let key: KeyEquivalent = switch settings.hotKeyKeyCode {
        case HotKeyDefaults.keyC:
            KeyEquivalent("c")
        case HotKeyDefaults.keyH:
            KeyEquivalent("h")
        default:
            KeyEquivalent("v")
        }

        let modifiers: EventModifiers = switch settings.hotKeyModifiers {
        case HotKeyDefaults.controlOption:
            [.control, .option]
        case HotKeyDefaults.controlCommand:
            [.control, .command]
        default:
            [.command, .option]
        }

        return (key, modifiers)
    }

    var body: some View {
        if appModel.history.entries.isEmpty {
            Text("Sin historial")
                .foregroundStyle(.secondary)
        } else {
            ForEach(appModel.history.entries.prefix(8)) { entry in
                Button {
                    appModel.restoreAndPaste(entry)
                } label: {
                    ClipboardEntryMenuLabel(entry: entry)
                        .environmentObject(appModel)
                }
            }

            Divider()
        }

        Button("Abrir historial") {
            appModel.showHistory()
        }
        .keyboardShortcut(openHistoryShortcut.key, modifiers: openHistoryShortcut.modifiers)

        SettingsLink {
            Text("Ajustes")
        }

        Button("Limpiar historial", role: .destructive) {
            appModel.clearHistory()
        }
        .disabled(appModel.history.entries.isEmpty)

        Divider()

        Button("Salir") {
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct ClipboardEntryMenuLabel: View {
    @EnvironmentObject private var appModel: AppModel
    let entry: ClipboardEntry

    var body: some View {
        HStack(spacing: 8) {
            if entry.kind == .image, let image = appModel.history.image(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: entry.kind == .text ? "text.alignleft" : "photo")
                    .frame(width: 22)
            }

            Text(entry.isPinned ? "📌 \(entry.title)" : entry.title)
            Text(RelativeDateFormatter.string(from: entry.createdAt))
                .foregroundStyle(.secondary)
        }
    }
}
