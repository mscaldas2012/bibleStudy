/// BibleCanon.swift
/// Static catalogue of all 66 canonical books with abbreviations, section groupings,
/// and per-chapter verse counts loaded from verse_counts.json.

import Foundation

// MARK: - Section

enum BibleSection: String, CaseIterable, Identifiable, Hashable {
    case torah           = "Torah"
    case otHistory       = "OT History"
    case wisdom          = "Wisdom"
    case majorProphets   = "Major Prophets"
    case minorProphets   = "Minor Prophets"
    case gospels         = "Gospels"
    case ntHistory       = "NT History"
    case pauline         = "Pauline Letters"
    case generalLetters  = "General Letters"
    case prophecy        = "Prophecy"

    var id: String { rawValue }

    /// Number of grid columns to use in the book picker for this section.
    var pickerColumns: Int {
        switch self {
        case .torah:          return 5   // 5 books  → 1 row
        case .otHistory:      return 6   // 12 books → 2 rows
        case .wisdom:         return 5   // 5 books  → 1 row
        case .majorProphets:  return 5   // 5 books  → 1 row
        case .minorProphets:  return 6   // 12 books → 2 rows
        case .gospels:        return 4   // 4 books  → 1 row
        case .ntHistory:      return 1   // 1 book   → 1 row (full-width chip)
        case .pauline:        return 7   // 13 books → 2 rows
        case .generalLetters: return 4   // 8 books  → 2 rows
        case .prophecy:       return 1   // 1 book   → 1 row (full-width chip)
        }
    }

    var testament: Testament {
        switch self {
        case .torah, .otHistory, .wisdom, .majorProphets, .minorProphets: return .old
        case .gospels, .ntHistory, .pauline, .generalLetters, .prophecy:  return .new
        }
    }
}

enum Testament: String, CaseIterable {
    case old = "Old Testament"
    case new = "New Testament"
}

// MARK: - Book

struct BibleBook: Identifiable, Hashable {
    let id: Int             // 1-based canonical order
    let name: String        // key in verse_counts.json
    let abbreviation: String
    let section: BibleSection

    /// Verse counts per chapter, loaded lazily from shared store.
    var chapterVerseCounts: [Int] { BibleCanon.verseCounts[name] ?? [] }
    var chapterCount: Int { chapterVerseCounts.count }
}

// MARK: - Canon

enum BibleCanon {
    // MARK: Verse counts

    static let verseCounts: [String: [Int]] = {
        guard let url = Bundle.main.url(forResource: "verse_counts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: [Int]].self, from: data)
        else { return [:] }
        return dict
    }()

    // MARK: Books

    static let books: [BibleBook] = [
        // ── Torah (5) ─────────────────────────────────────────────────────────
        BibleBook(id:  1, name: "Genesis",        abbreviation: "Gen",  section: .torah),
        BibleBook(id:  2, name: "Exodus",         abbreviation: "Exod", section: .torah),
        BibleBook(id:  3, name: "Leviticus",      abbreviation: "Lev",  section: .torah),
        BibleBook(id:  4, name: "Numbers",        abbreviation: "Num",  section: .torah),
        BibleBook(id:  5, name: "Deuteronomy",    abbreviation: "Deut", section: .torah),

        // ── OT History (12) ───────────────────────────────────────────────────
        BibleBook(id:  6, name: "Joshua",         abbreviation: "Josh", section: .otHistory),
        BibleBook(id:  7, name: "Judges",         abbreviation: "Judg", section: .otHistory),
        BibleBook(id:  8, name: "Ruth",           abbreviation: "Ruth", section: .otHistory),
        BibleBook(id:  9, name: "1 Samuel",       abbreviation: "1Sam", section: .otHistory),
        BibleBook(id: 10, name: "2 Samuel",       abbreviation: "2Sam", section: .otHistory),
        BibleBook(id: 11, name: "1 Kings",        abbreviation: "1Kgs", section: .otHistory),
        BibleBook(id: 12, name: "2 Kings",        abbreviation: "2Kgs", section: .otHistory),
        BibleBook(id: 13, name: "1 Chronicles",   abbreviation: "1Chr", section: .otHistory),
        BibleBook(id: 14, name: "2 Chronicles",   abbreviation: "2Chr", section: .otHistory),
        BibleBook(id: 15, name: "Ezra",           abbreviation: "Ezra", section: .otHistory),
        BibleBook(id: 16, name: "Nehemiah",       abbreviation: "Neh",  section: .otHistory),
        BibleBook(id: 17, name: "Esther",         abbreviation: "Esth", section: .otHistory),

        // ── Wisdom (5) ────────────────────────────────────────────────────────
        BibleBook(id: 18, name: "Job",            abbreviation: "Job",  section: .wisdom),
        BibleBook(id: 19, name: "Psalms",         abbreviation: "Ps",   section: .wisdom),
        BibleBook(id: 20, name: "Proverbs",       abbreviation: "Prov", section: .wisdom),
        BibleBook(id: 21, name: "Ecclesiastes",   abbreviation: "Eccl", section: .wisdom),
        BibleBook(id: 22, name: "Song of Solomon",abbreviation: "Song", section: .wisdom),

        // ── Major Prophets (5) ────────────────────────────────────────────────
        BibleBook(id: 23, name: "Isaiah",         abbreviation: "Isa",  section: .majorProphets),
        BibleBook(id: 24, name: "Jeremiah",       abbreviation: "Jer",  section: .majorProphets),
        BibleBook(id: 25, name: "Lamentations",   abbreviation: "Lam",  section: .majorProphets),
        BibleBook(id: 26, name: "Ezekiel",        abbreviation: "Ezek", section: .majorProphets),
        BibleBook(id: 27, name: "Daniel",         abbreviation: "Dan",  section: .majorProphets),

        // ── Minor Prophets (12) ───────────────────────────────────────────────
        BibleBook(id: 28, name: "Hosea",          abbreviation: "Hos",  section: .minorProphets),
        BibleBook(id: 29, name: "Joel",           abbreviation: "Joel", section: .minorProphets),
        BibleBook(id: 30, name: "Amos",           abbreviation: "Amos", section: .minorProphets),
        BibleBook(id: 31, name: "Obadiah",        abbreviation: "Obad", section: .minorProphets),
        BibleBook(id: 32, name: "Jonah",          abbreviation: "Jonah",section: .minorProphets),
        BibleBook(id: 33, name: "Micah",          abbreviation: "Mic",  section: .minorProphets),
        BibleBook(id: 34, name: "Nahum",          abbreviation: "Nah",  section: .minorProphets),
        BibleBook(id: 35, name: "Habakkuk",       abbreviation: "Hab",  section: .minorProphets),
        BibleBook(id: 36, name: "Zephaniah",      abbreviation: "Zeph", section: .minorProphets),
        BibleBook(id: 37, name: "Haggai",         abbreviation: "Hag",  section: .minorProphets),
        BibleBook(id: 38, name: "Zechariah",      abbreviation: "Zech", section: .minorProphets),
        BibleBook(id: 39, name: "Malachi",        abbreviation: "Mal",  section: .minorProphets),

        // ── Gospels (4) ───────────────────────────────────────────────────────
        BibleBook(id: 40, name: "Matthew",        abbreviation: "Matt", section: .gospels),
        BibleBook(id: 41, name: "Mark",           abbreviation: "Mark", section: .gospels),
        BibleBook(id: 42, name: "Luke",           abbreviation: "Luke", section: .gospels),
        BibleBook(id: 43, name: "John",           abbreviation: "John", section: .gospels),

        // ── NT History (1) ────────────────────────────────────────────────────
        BibleBook(id: 44, name: "Acts",           abbreviation: "Acts", section: .ntHistory),

        // ── Pauline Letters (13) ──────────────────────────────────────────────
        BibleBook(id: 45, name: "Romans",         abbreviation: "Rom",  section: .pauline),
        BibleBook(id: 46, name: "1 Corinthians",  abbreviation: "1Cor", section: .pauline),
        BibleBook(id: 47, name: "2 Corinthians",  abbreviation: "2Cor", section: .pauline),
        BibleBook(id: 48, name: "Galatians",      abbreviation: "Gal",  section: .pauline),
        BibleBook(id: 49, name: "Ephesians",      abbreviation: "Eph",  section: .pauline),
        BibleBook(id: 50, name: "Philippians",    abbreviation: "Phil", section: .pauline),
        BibleBook(id: 51, name: "Colossians",     abbreviation: "Col",  section: .pauline),
        BibleBook(id: 52, name: "1 Thessalonians",abbreviation: "1Thes",section: .pauline),
        BibleBook(id: 53, name: "2 Thessalonians",abbreviation: "2Thes",section: .pauline),
        BibleBook(id: 54, name: "1 Timothy",      abbreviation: "1Tim", section: .pauline),
        BibleBook(id: 55, name: "2 Timothy",      abbreviation: "2Tim", section: .pauline),
        BibleBook(id: 56, name: "Titus",          abbreviation: "Titus",section: .pauline),
        BibleBook(id: 57, name: "Philemon",       abbreviation: "Phlm", section: .pauline),

        // ── General Letters (8) ───────────────────────────────────────────────
        BibleBook(id: 58, name: "Hebrews",        abbreviation: "Heb",  section: .generalLetters),
        BibleBook(id: 59, name: "James",          abbreviation: "Jas",  section: .generalLetters),
        BibleBook(id: 60, name: "1 Peter",        abbreviation: "1Pet", section: .generalLetters),
        BibleBook(id: 61, name: "2 Peter",        abbreviation: "2Pet", section: .generalLetters),
        BibleBook(id: 62, name: "1 John",         abbreviation: "1John",section: .generalLetters),
        BibleBook(id: 63, name: "2 John",         abbreviation: "2Jn",  section: .generalLetters),
        BibleBook(id: 64, name: "3 John",         abbreviation: "3Jn",  section: .generalLetters),
        BibleBook(id: 65, name: "Jude",           abbreviation: "Jude", section: .generalLetters),

        // ── Prophecy (1) ──────────────────────────────────────────────────────
        BibleBook(id: 66, name: "Revelation",     abbreviation: "Rev",  section: .prophecy),
    ]

    // MARK: Lookups

    static func books(in section: BibleSection) -> [BibleBook] {
        books.filter { $0.section == section }
    }

    static func books(in testament: Testament) -> [BibleSection: [BibleBook]] {
        let sections = BibleSection.allCases.filter { $0.testament == testament }
        return Dictionary(uniqueKeysWithValues: sections.map { ($0, books(in: $0)) })
    }
}
