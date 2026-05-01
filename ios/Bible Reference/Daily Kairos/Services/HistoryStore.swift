/// HistoryStore.swift
/// Persists successful lookups locally via UserDefaults.
/// To enable iCloud sync later: add iCloud → Key-value storage capability,
/// then swap UserDefaults calls for NSUbiquitousKeyValueStore.

import Foundation
import Observation

@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    private(set) var entries: [HistoryEntry] = []

    private let storageKey = "lookup_history_v1"
    private let maxEntries = 50

    private init() {
        load()
    }

    // MARK: - Public API

    /// Record a successful lookup. Deduplicates by displayTitle — moves to top if already present.
    func add(query: String, displayTitle: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = displayTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        entries.removeAll { $0.displayTitle.caseInsensitiveCompare(trimmedTitle) == .orderedSame }
        entries.insert(HistoryEntry(query: trimmedQuery, displayTitle: trimmedTitle), at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }
}
