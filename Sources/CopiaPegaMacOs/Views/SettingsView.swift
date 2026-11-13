import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var maxItems: Binding<Double> {
        Binding {
            Double(appModel.settingsStore.settings.maxItems)
        } set: { value in
            appModel.settingsStore.settings.maxItems = min(200, max(5, Int(value)))
        }
    }

    private var retentionHours: Binding<Double> {
        Binding {
            Double(appModel.settingsStore.settings.retentionHours)
        } set: { value in
            appModel.settingsStore.settings.retentionHours = min(168, max(1, Int(value)))
        }
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Iniciar al arrancar macOS", isOn: $appModel.loginItemService.isEnabled)
                    .help("La app se iniciará automáticamente cuando enciendas tu Mac")

                if let loginError = appModel.loginItemService.lastError {
                    Text("No se pudo actualizar el inicio automático: \(loginError)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("Accesibilidad (pegar automático)")
                    Spacer()
                    if appModel.isAccessibilityTrusted {
                        Text("Concedido")
                            .foregroundStyle(.green)
                    } else {
                        Button("Permitir") {
                            _ = appModel.pasteAutomation.requestAccessibilityPermission()
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }

                HStack {
                    Text("Versión")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Historial") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Elementos")
                        Spacer()
                        Text("\(appModel.settingsStore.settings.maxItems)")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: maxItems, in: 5...200, step: 5)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Retención")
                        Spacer()
                        Text("\(appModel.settingsStore.settings.retentionHours) h")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: retentionHours, in: 1...168, step: 1)
                }

                Toggle("Guardar imágenes", isOn: Binding {
                    appModel.settingsStore.settings.saveImages
                } set: { value in
                    appModel.settingsStore.settings.saveImages = value
                })

                Picker("Pegar desde el historial", selection: Binding {
                    appModel.settingsStore.settings.pasteClickCount
                } set: { value in
                    appModel.settingsStore.settings.pasteClickCount = value
                }) {
                    ForEach(PasteClickMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Atajo global") {
                Picker("Modificadores", selection: Binding {
                    appModel.settingsStore.settings.hotKeyModifiers
                } set: { value in
                    appModel.settingsStore.settings.hotKeyModifiers = value
                }) {
                    ForEach(HotKeyChoices.modifiers) { choice in
                        Text(choice.name).tag(choice.modifiers)
                    }
                }

                Picker("Tecla", selection: Binding {
                    appModel.settingsStore.settings.hotKeyKeyCode
                } set: { value in
                    appModel.settingsStore.settings.hotKeyKeyCode = value
                }) {
                    ForEach(HotKeyChoices.keys) { choice in
                        Text(choice.name).tag(choice.keyCode)
                    }
                }

                if appModel.hotKey.registrationFailed {
                    Text("Este atajo ya está ocupado por otra aplicación. Prueba con otra combinación.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Button("Restablecer ajustes") {
                    appModel.settingsStore.reset()
                }

                Button("Limpiar historial", role: .destructive) {
                    appModel.clearHistory()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            appModel.refreshSystemStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appModel.refreshSystemStatus()
        }
    }
}
