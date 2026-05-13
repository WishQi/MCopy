import Foundation
import SwiftData
import AppKit

enum ClipboardContentType: String, Codable {
    case text
    case image
    case url
    case file
}

@Model
final class ClipboardItem {
    var id: UUID
    var contentType: String
    var textContent: String?
    var imageData: Data?
    var timestamp: Date

    init(contentType: ClipboardContentType, textContent: String? = nil, imageData: Data? = nil) {
        self.id = UUID()
        self.contentType = contentType.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.timestamp = Date()
    }

    var type: ClipboardContentType {
        ClipboardContentType(rawValue: contentType) ?? .text
    }

    func writeToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch type {
        case .text, .url:
            if let text = textContent {
                pb.setString(text, forType: .string)
            }
        case .image:
            if let data = imageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        case .file:
            let urls = (textContent ?? "")
                .components(separatedBy: "\n")
                .map { URL(fileURLWithPath: $0) as NSURL }
            pb.writeObjects(urls)
        }
    }
}
