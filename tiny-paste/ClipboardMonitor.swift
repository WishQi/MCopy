import AppKit
import SwiftData

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let modelContext: ModelContext
    private(set) var shouldIgnoreNextChange = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreNextChange() {
        shouldIgnoreNextChange = true
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if shouldIgnoreNextChange {
            shouldIgnoreNextChange = false
            return
        }

        guard let item = extractItem(from: pb) else { return }

        // Deduplicate against the most recent saved item
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let recent = try? modelContext.fetch(descriptor).first {
            if recent.contentType == item.contentType && recent.textContent == item.textContent {
                return
            }
        }

        modelContext.insert(item)
        try? modelContext.save()
    }

    private func extractItem(from pb: NSPasteboard) -> ClipboardItem? {
        // Image first
        if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
           let tiff = image.tiffRepresentation {
            return ClipboardItem(contentType: .image, imageData: tiff)
        }

        // File URLs
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: fileOptions)?
            .compactMap({ $0 as? URL }),
           !urls.isEmpty {
            let paths = urls.map(\.path).joined(separator: "\n")
            return ClipboardItem(contentType: .file, textContent: paths)
        }

        // String → detect URL vs plain text
        if let text = pb.string(forType: .string), !text.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed),
               let scheme = url.scheme, !scheme.isEmpty,
               url.host != nil {
                return ClipboardItem(contentType: .url, textContent: trimmed)
            }
            return ClipboardItem(contentType: .text, textContent: text)
        }

        return nil
    }
}
