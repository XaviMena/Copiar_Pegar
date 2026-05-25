import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

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
        .keyboardShortcut("v", modifiers: [.command, .option])

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
