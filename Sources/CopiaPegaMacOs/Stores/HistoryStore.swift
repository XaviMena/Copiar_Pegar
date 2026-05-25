import AppKit
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []

    let baseURL: URL
    let imagesURL: URL
    private let indexURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.baseURL = support.appendingPathComponent("CopiaPegaMacOs", isDirectory: true)
        self.imagesURL = baseURL.appendingPathComponent("Images", isDirectory: true)
        self.indexURL = baseURL.appendingPathComponent("history.json")

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        ensureDirectories(fileManager: fileManager)
        load()
    }

    func addText(_ text: String, hash: String, settings: AppSettings) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return
        }
        add(.text(cleanText, hash: hash), settings: settings)
    }

    func addImage(_ image: NSImage, data: Data, hash: String, settings: AppSettings) {
        let fileName = "\(UUID().uuidString).png"
        let fileURL = imagesURL.appendingPathComponent(fileName)
        guard data.writeSafely(to: fileURL) else {
            return
        }

        let entry = ClipboardEntry.image(
            fileName: fileName,
            width: Int(image.size.width),
            height: Int(image.size.height),
            hash: hash
        )
        add(entry, settings: settings)
    }

    func imageURL(for entry: ClipboardEntry) -> URL? {
        guard let fileName = entry.imageFileName else {
            return nil
        }
        return imagesURL.appendingPathComponent(fileName)
    }

    func image(for entry: ClipboardEntry) -> NSImage? {
        guard let url = imageURL(for: entry) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    func prune(settings: AppSettings) {
        let cutoff = Date().addingTimeInterval(TimeInterval(-max(1, settings.retentionHours) * 3_600))
        
        let pinned = entries.filter { $0.isPinned }
        let unpinned = entries.filter { !$0.isPinned }
        
        var keptUnpinned = unpinned.filter { $0.createdAt >= cutoff }
        let maxUnpinned = max(0, settings.maxItems - pinned.count)
        if keptUnpinned.count > maxUnpinned {
            keptUnpinned = Array(keptUnpinned.prefix(maxUnpinned))
        }
        
        let allowedIDs = Set(pinned.map(\.id) + keptUnpinned.map(\.id))
        let kept = entries.filter { allowedIDs.contains($0.id) }
        
        removeImageFilesNotReferenced(by: kept)
        entries = kept
        save()
    }

    func clear() {
        let kept = entries.filter { $0.isPinned }
        entries = kept
        save()
        removeImageFilesNotReferenced(by: kept)
    }

    func togglePin(_ entry: ClipboardEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isPinned.toggle()
            save()
        }
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
        removeImageFilesNotReferenced(by: entries)
    }

    private func add(_ entry: ClipboardEntry, settings: AppSettings) {
        if entries.first?.contentHash == entry.contentHash {
            return
        }

        var isPinned = false
        if let existing = entries.first(where: { $0.contentHash == entry.contentHash }) {
            isPinned = existing.isPinned
        }

        entries.removeAll { $0.contentHash == entry.contentHash }
        
        var newEntry = entry
        newEntry.isPinned = isPinned
        
        entries.insert(newEntry, at: 0)
        prune(settings: settings)
        save()
    }

    private func ensureDirectories(fileManager: FileManager) {
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else {
            entries = []
            return
        }
        entries = (try? decoder.decode([ClipboardEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(entries) else {
            return
        }
        _ = data.writeSafely(to: indexURL)
    }

    private func removeImageFilesNotReferenced(by kept: [ClipboardEntry]) {
        let referenced = Set(kept.compactMap(\.imageFileName))
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesURL.path) else {
            return
        }
        for file in files where !referenced.contains(file) {
            try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(file))
        }
    }

    private func removeAllImages() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesURL.path) else {
            return
        }
        for file in files {
            try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(file))
        }
    }
}

private extension Data {
    func writeSafely(to url: URL) -> Bool {
        do {
            try write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
