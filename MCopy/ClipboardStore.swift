import Foundation
import SwiftData

/// LRU-style storage for `ClipboardItem`.
///
/// Recency is encoded in `timestamp` (descending = most-recently-used first),
/// so the existing `@Query(sort: \.timestamp, order: .reverse)` in the UI
/// reflects LRU order without further changes.
///
/// Capacity is enforced on every mutation: items past `capacity` are deleted.
final class ClipboardStore {
    static let capacity = 20

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Insert a new clipboard item at the front. If an identical entry
    /// (same content type + payload) is already the most recent, it is
    /// touched instead of duplicated. Evicts oldest entries beyond capacity.
    @discardableResult
    func insert(_ item: ClipboardItem) -> ClipboardItem {
        if let existing = findDuplicate(of: item) {
            touch(existing)
            return existing
        }
        modelContext.insert(item)
        item.timestamp = Date()
        evictIfNeeded()
        try? modelContext.save()
        return item
    }

    /// Mark `item` as most-recently-used: update its timestamp to now so it
    /// surfaces at the front of the timestamp-descending query.
    func touch(_ item: ClipboardItem) {
        item.timestamp = Date()
        try? modelContext.save()
    }

    /// Returns true if an item with the same content already sits at the front.
    private func findDuplicate(of item: ClipboardItem) -> ClipboardItem? {
        let all = (try? modelContext.fetch(
            FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        )) ?? []
        return all.first { $0.contentType == item.contentType && $0.textContent == item.textContent && $0.imageData == item.imageData }
    }

    /// Delete entries past the capacity (the oldest by timestamp).
    private func evictIfNeeded() {
        let all = (try? modelContext.fetch(
            FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        )) ?? []
        guard all.count > Self.capacity else { return }
        for stale in all[Self.capacity...] {
            modelContext.delete(stale)
        }
    }
}
