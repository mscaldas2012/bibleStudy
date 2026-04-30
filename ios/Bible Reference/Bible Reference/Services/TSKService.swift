/// TSKService.swift
/// Queries the bundled TSK (Treasury of Scripture Knowledge) SQLite database
/// for cross-references. Uses raw libsqlite3 — no Swift packages needed.

import Foundation
import SQLite3

struct CrossRef: Identifiable {
    let id = UUID()
    let reference: String      // e.g. "Romans 5:8"
    var explanation: String    // filled in by Apple Foundation Models
}

actor TSKService {
    static let shared = TSKService()

    private var db: OpaquePointer?

    private init() {
        guard let url = Bundle.main.url(forResource: "tsk", withExtension: "sqlite") else {
            return
        }
        sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil)
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    /// Returns up to `limit` cross-references for the given passage, ordered by vote count.
    /// For multi-verse passages, unions refs from all individual verses.
    func fetchRefs(for ref: BibleReference, limit: Int = 6) -> [CrossRef] {
        guard let db else { return [] }

        // For whole-chapter or verse-range refs, collect from all constituent verses.
        // For simplicity cap at 3 verses to avoid an oversized prompt.
        let verses = constituentVerses(ref, max: 3)

        var seen = Set<String>()
        var results: [CrossRef] = []

        for (book, chapter, verse) in verses {
            let refs = query(db: db, book: book, chapter: chapter, verse: verse, limit: limit)
            for r in refs where !seen.contains(r.reference) {
                seen.insert(r.reference)
                results.append(r)
                if results.count >= limit { return results }
            }
        }
        return results
    }

    // MARK: - Private

    private func query(db: OpaquePointer, book: String, chapter: Int, verse: Int, limit: Int) -> [CrossRef] {
        let sql = """
            SELECT to_book, to_chapter, to_verse_start, to_verse_end
            FROM cross_refs
            WHERE from_book = ? AND from_chapter = ? AND from_verse = ?
            ORDER BY votes DESC
            LIMIT ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (book as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(chapter))
        sqlite3_bind_int(stmt, 3, Int32(verse))
        sqlite3_bind_int(stmt, 4, Int32(limit))

        var refs: [CrossRef] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let toBook = String(cString: sqlite3_column_text(stmt, 0))
            let toChapter = Int(sqlite3_column_int(stmt, 1))
            let toVerseStart = Int(sqlite3_column_int(stmt, 2))
            let toVerseEnd = Int(sqlite3_column_int(stmt, 3))

            let refString: String
            if toVerseStart == toVerseEnd {
                refString = "\(toBook) \(toChapter):\(toVerseStart)"
            } else {
                refString = "\(toBook) \(toChapter):\(toVerseStart)-\(toVerseEnd)"
            }
            refs.append(CrossRef(reference: refString, explanation: ""))
        }
        return refs
    }

    /// Returns up to `max` (book, chapter, verse) tuples that the BibleReference spans.
    private func constituentVerses(_ ref: BibleReference, max: Int) -> [(String, Int, Int)] {
        var result: [(String, Int, Int)] = []

        // Single verse or small range within one chapter
        if ref.chapterStart == ref.chapterEnd {
            let vs = ref.verseStart ?? 1
            let ve = ref.verseEnd ?? vs
            for v in vs...min(ve, vs + max - 1) {
                result.append((ref.book, ref.chapterStart, v))
            }
        } else {
            // Multi-chapter: just use verse 1 of each chapter (up to max)
            for ch in ref.chapterStart...min(ref.chapterEnd, ref.chapterStart + max - 1) {
                result.append((ref.book, ch, 1))
            }
        }
        return result
    }
}
