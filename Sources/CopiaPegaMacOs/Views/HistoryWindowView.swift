import SwiftUI

// MARK: - Main Window

struct HistoryWindowView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: ClipboardEntry.ID?
    @State private var searchText = ""
    @State private var showSearch = false

    private var selectedEntry: ClipboardEntry? {
        appModel.history.entries.first { $0.id == selection }
    }

    private var filteredEntries: [ClipboardEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appModel.history.entries }

        return appModel.history.entries.filter { entry in
            if entry.kind == .text, let text = entry.text {
                return text.lowercased().contains(query)
            }
            return entry.title.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Minimal Header ──
            HStack {
                Text("Historial")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Search toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                        if !showSearch { searchText = "" }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(showSearch ? Color.accentColor : Color.secondary.opacity(0.5))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Buscar (⌘F)")

                // Close
                Button {
                    appModel.closeHistoryWindow?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle().fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Cerrar (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, showSearch ? 8 : 12)

            // ── Collapsible Search ──
            if showSearch {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    TextField("Buscar...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.primary.opacity(0.04))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── Subtle separator ──
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            // ── Items List ──
            if filteredEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredEntries) { entry in
                            ClipboardItemRow(
                                entry: entry,
                                isSelected: selection == entry.id,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        selection = entry.id
                                    }
                                },
                                onPaste: {
                                    appModel.restoreAndPaste(entry)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }

            // ── Keyboard Hints Footer ──
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            HStack(spacing: 16) {
                shortcutHint("↩", "Pegar")
                shortcutHint("⌫", "Eliminar")
                shortcutHint("esc", "Cerrar")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            // ── Hidden Keyboard Shortcuts ──
            hiddenShortcuts
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: searchText.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 24, weight: .thin))
                .foregroundStyle(.quaternary)
            Text(searchText.isEmpty ? "Historial vacío" : "Sin resultados")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shortcut Hint

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.primary.opacity(0.04))
                )
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Hidden Shortcuts

    @ViewBuilder
    private var hiddenShortcuts: some View {
        if let selectedEntry {
            Button("") { appModel.restoreAndPaste(selectedEntry) }
                .keyboardShortcut(.defaultAction)
                .opacity(0).frame(width: 0, height: 0)

            Button("") {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    appModel.delete(selectedEntry)
                    selection = nil
                }
            }
            .keyboardShortcut(.delete, modifiers: [])
            .opacity(0).frame(width: 0, height: 0)
        }

        Button("") { appModel.closeHistoryWindow?() }
            .keyboardShortcut(.cancelAction)
            .opacity(0).frame(width: 0, height: 0)

        // Cmd+F to toggle search
        Button("") {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSearch.toggle()
                if !showSearch { searchText = "" }
            }
        }
        .keyboardShortcut("f", modifiers: .command)
        .opacity(0).frame(width: 0, height: 0)
    }
}

// MARK: - Clipboard Item Row

private struct ClipboardItemRow: View {
    @EnvironmentObject private var appModel: AppModel
    let entry: ClipboardEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // ── Thumbnail ──
            thumbnail
                .frame(width: 40, height: 40)

            // ── Content ──
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind == .text ? (entry.text ?? "") : entry.title)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 3) {
                    Text(entry.detail)
                    Text("·")
                    Text(RelativeDateFormatter.string(from: entry.createdAt))
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            // ── Hover Actions ──
            if isHovered || entry.isPinned {
                hoverActions
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onPaste() }
        .onTapGesture(count: 1) { onSelect() }
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = h
            }
        }
    }

    // MARK: Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        if entry.kind == .image, let image = appModel.history.image(for: entry) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.tertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        }
    }

    // MARK: Hover Actions

    private var hoverActions: some View {
        HStack(spacing: 2) {
            if entry.isPinned || isHovered {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        appModel.togglePin(entry)
                    }
                } label: {
                    Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(entry.isPinned ? Color.accentColor : Color.secondary.opacity(0.5))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(entry.isPinned ? "Desfijar" : "Fijar")
            }

            if isHovered {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        appModel.delete(entry)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Eliminar")
            }
        }
    }

    // MARK: Row Background

    private var rowBackground: some View {
        Group {
            if entry.isPinned {
                // Pinned: subtle blue macOS border
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(isSelected ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
            } else if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
            } else {
                Color.clear
            }
        }
    }
}
