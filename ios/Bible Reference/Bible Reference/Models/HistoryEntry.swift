/// HistoryEntry.swift
/// A single successful lookup stored in history.

import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let query: String        // original text the user typed — shown in the list
    let displayTitle: String // canonical passage title shown after lookup ("John 3:16", "Luke 15:11–32")
    let timestamp: Date

    init(query: String, displayTitle: String) {
        self.id = UUID()
        self.query = query
        self.displayTitle = displayTitle
        self.timestamp = Date()
    }
}
