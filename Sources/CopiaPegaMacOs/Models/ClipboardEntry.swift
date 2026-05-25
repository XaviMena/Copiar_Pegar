import Foundation

enum ClipboardContentKind: String, Codable, CaseIterable {
    case text
    case image
}

struct ClipboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: ClipboardContentKind
    var createdAt: Date
    var contentHash: String
    var text: String?
    var imageFileName: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, createdAt, contentHash, text, imageFileName, imageWidth, imageHeight, isPinned
    }

    init(id: UUID, kind: ClipboardContentKind, createdAt: Date, contentHash: String, text: String?, imageFileName: String?, imageWidth: Int?, imageHeight: Int?, isPinned: Bool = false) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.text = text
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ClipboardContentKind.self, forKey: .kind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    var title: String {
        switch kind {
        case .text:
            let value = text?.replacingOccurrences(of: "\n", with: " ") ?? ""
            return value.truncated(to: 30)
        case .image:
            if let imageWidth, let imageHeight {
                return "Imagen \(imageWidth)x\(imageHeight)"
            }
            return "Imagen"
        }
    }

    var detail: String {
        switch kind {
        case .text:
            return "Texto"
        case .image:
            return "Imagen"
        }
    }
}

extension ClipboardEntry {
    static func text(_ value: String, hash: String, date: Date = Date()) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            kind: .text,
            createdAt: date,
            contentHash: hash,
            text: value,
            imageFileName: nil,
            imageWidth: nil,
            imageHeight: nil,
            isPinned: false
        )
    }

    static func image(fileName: String, width: Int?, height: Int?, hash: String, date: Date = Date()) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            kind: .image,
            createdAt: date,
            contentHash: hash,
            text: nil,
            imageFileName: fileName,
            imageWidth: width,
            imageHeight: height,
            isPinned: false
        )
    }
}
