import AppKit
import CryptoKit
import Foundation

@MainActor
final class ClipboardService {
    private let pasteboard: NSPasteboard
    private var ignoredChangeCount: Int?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func shouldIgnore(changeCount: Int) -> Bool {
        guard let ignoredChangeCount else {
            return false
        }
        self.ignoredChangeCount = nil
        return ignoredChangeCount == changeCount
    }

    func readCurrent(saveImages: Bool) -> ClipboardPayload? {
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text, hash: Self.hash(Data(text.utf8)))
        }

        guard saveImages else {
            return nil
        }

        guard let image = NSImage(pasteboard: pasteboard), let data = image.pngData else {
            return nil
        }

        return .image(image, data: data, hash: Self.hash(data))
    }

    func restore(_ entry: ClipboardEntry, history: HistoryStore) {
        switch entry.kind {
        case .text:
            guard let text = entry.text else {
                return
            }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        case .image:
            guard let image = history.image(for: entry) else {
                return
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        }

        ignoredChangeCount = pasteboard.changeCount
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum ClipboardPayload {
    case text(String, hash: String)
    case image(NSImage, data: Data, hash: String)
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
