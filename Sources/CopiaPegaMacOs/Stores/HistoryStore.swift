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
    private let imageCache = NSCache<NSString, NSImage>()

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
        self.imageCache.countLimit = 100

        ensureDirectories(fileManager: fileManager)
        load()
    }

    func addText(_ text: String, hash: String, settings: AppSettings) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        add(.text(text, hash: hash), settings: settings)
    }

    func addImage(_ image: NSImage, data: Data, hash: String, settings: AppSettings) {
        if entries.first?.contentHash == hash {
            return
        }

        let fileName: String
        if let existingFileName = entries.first(where: { $0.contentHash == hash })?.imageFileName,
           FileManager.default.fileExists(atPath: imagesURL.appendingPathComponent(existingFileName).path) {
            fileName = existingFileName
        } else {
            let newFileName = "\(UUID().uuidString).png"
            let fileURL = imagesURL.appendingPathComponent(newFileName)
            guard data.writeSafely(to: fileURL) else {
                return
            }
            fileName = newFileName
        }

        imageCache.setObject(image, forKey: fileName as NSString)

        let pixelRep = image.representations.first
        let width = (pixelRep?.pixelsWide ?? 0) > 0 ? pixelRep?.pixelsWide : Int(image.size.width)
        let height = (pixelRep?.pixelsHigh ?? 0) > 0 ? pixelRep?.pixelsHigh : Int(image.size.height)

        let entry = ClipboardEntry.image(
            fileName: fileName,
            width: width,
            height: height,
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
        guard let fileName = entry.imageFileName else {
            return nil
        }
        if let cached = imageCache.object(forKey: fileName as NSString) {
            return cached
        }
        let url = imagesURL.appendingPathComponent(fileName)
        guard let loaded = NSImage(contentsOf: url) else {
            return nil
        }
        imageCache.setObject(loaded, forKey: fileName as NSString)
        return loaded
    }

    func prune(settings: AppSettings) {
        let changed = pruneInMemory(settings: settings)
        if changed {
            save()
        }
    }

    func clear() {
        let kept = entries.filter { $0.isPinned }
        entries = kept
        save()
        removeImageFilesNotReferenced(by: kept)
    }

    func togglePin(_ entry: ClipboardEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            let shouldPin = !entries[index].isPinned
            entries[index].isPinned = shouldPin

            if shouldPin {
                let pinnedEntry = entries.remove(at: index)
                entries.insert(pinnedEntry, at: 0)
            }

            save()
        }
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
        removeImageFilesNotReferenced(by: entries)
    }

    @discardableResult
    private func pruneInMemory(settings: AppSettings) -> Bool {
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
        let changed = kept != entries

        if changed {
            entries = kept
        }
        removeImageFilesNotReferenced(by: kept)
        return changed
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
        _ = pruneInMemory(settings: settings)
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
            imageCache.removeObject(forKey: file as NSString)
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
