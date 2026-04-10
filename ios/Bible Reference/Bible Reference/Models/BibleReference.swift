/// BibleReference.swift
/// Parses Bible reference strings and counts verses.
/// Ported from cli/bible_study/parser.py and verse_counter.py.

import Foundation

// MARK: - Data loading

private let _aliasData: (canonical: [String], aliases: [String: String]) = {
    guard let url = Bundle.main.url(forResource: "book_aliases", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let raw = try? JSONDecoder().decode([String: AnyCodable].self, from: data)
    else { return ([], [:]) }

    let canonical = (raw["canonical"]?.value as? [String]) ?? []
    let aliases = (raw["aliases"]?.value as? [String: String]) ?? [:]
    return (canonical, aliases)
}()

private let _canonical: [String: String] = {
    var map: [String: String] = [:]
    for book in _aliasData.canonical {
        map[book.lowercased()] = book
    }
    for (alias, canon) in _aliasData.aliases {
        map[alias.lowercased()] = canon
    }
    return map
}()

private let _verseCountData: [String: [Int]] = {
    guard let url = Bundle.main.url(forResource: "verse_counts", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let dict = try? JSONDecoder().decode([String: [Int]].self, from: data)
    else { return [:] }
    return dict
}()

private let _singleChapterBooks: Set<String> = ["Obadiah", "Philemon", "2 John", "3 John", "Jude"]

// MARK: - BibleReference

struct BibleReference: Equatable {
    let book: String
    let chapterStart: Int
    let chapterEnd: Int
    let verseStart: Int?   // nil = whole chapter
    let verseEnd: Int?

    /// Display string, e.g. "John 3:16" or "Genesis 1-3"
    var displayTitle: String {
        if chapterStart == chapterEnd {
            if verseStart == nil { return "\(book) \(chapterStart)" }
            if verseStart == verseEnd { return "\(book) \(chapterStart):\(verseStart!)" }
            return "\(book) \(chapterStart):\(verseStart!)-\(verseEnd!)"
        }
        if verseStart == nil { return "\(book) \(chapterStart)-\(chapterEnd)" }
        return "\(book) \(chapterStart):\(verseStart!)-\(chapterEnd):\(verseEnd!)"
    }

    /// Same format accepted by the ESV API `q` parameter.
    var esvQuery: String { displayTitle }

    /// Total number of verses this reference spans.
    var verseCount: Int {
        guard let bookData = _verseCountData[book] else { return Int.max }
        let cs = chapterStart - 1
        let ce = chapterEnd - 1
        guard cs >= 0, ce < bookData.count else { return Int.max }

        // Whole-chapter reference
        if verseStart == nil {
            return bookData[cs...ce].reduce(0, +)
        }

        // Same-chapter verse range
        if cs == ce {
            let totalInChapter = bookData[cs]
            let vs = verseStart!
            let ve = verseEnd ?? totalInChapter
            return ve - vs + 1
        }

        // Cross-chapter range
        let vs = verseStart!
        let ve = verseEnd ?? bookData[ce]
        var count = bookData[cs] - vs + 1
        if ce > cs + 1 {
            count += bookData[(cs + 1)..<ce].reduce(0, +)
        }
        count += ve
        return count
    }

    /// True when ESV text should be fetched and displayed.
    /// Shows text for anything within a single chapter (any verse range or full chapter).
    /// Hides text for multi-chapter or whole-book requests.
    var shouldShowText: Bool { chapterStart == chapterEnd }
}

// MARK: - Parser

enum ParseError: LocalizedError {
    case unknownBook(String)
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .unknownBook(let raw):
            return "Unknown book: '\(raw)'. Try a book name like \"John\", \"Genesis\", or \"Ps\"."
        case .invalidFormat(let ref):
            return "Cannot parse '\(ref)'. Try formats like \"John 3:16\", \"Psalm 23\", or \"Genesis 1-3\"."
        }
    }
}

func parseBibleReference(_ input: String) throws -> BibleReference {
    let ref = input.trimmingCharacters(in: .whitespaces)

    // Pattern 1: Book Ch:V-Ch:V  (cross-chapter)
    if let m = ref.firstMatch(of: /(?i)^(?<book>.+?)\s+(?<cs>\d+):(?<vs>\d+)\s*[-–]\s*(?<ce>\d+):(?<ve>\d+)$/) {
        let book = try resolveBook(String(m.book))
        return BibleReference(book: book,
                              chapterStart: Int(m.cs)!, chapterEnd: Int(m.ce)!,
                              verseStart: Int(m.vs), verseEnd: Int(m.ve))
    }

    // Pattern 2: Book Ch:V-V  (same-chapter range)
    if let m = ref.firstMatch(of: /(?i)^(?<book>.+?)\s+(?<ch>\d+):(?<vs>\d+)\s*[-–]\s*(?<ve>\d+)$/) {
        let book = try resolveBook(String(m.book))
        let ch = Int(m.ch)!
        return BibleReference(book: book,
                              chapterStart: ch, chapterEnd: ch,
                              verseStart: Int(m.vs), verseEnd: Int(m.ve))
    }

    // Pattern 3: Book Ch:V  (single verse)
    if let m = ref.firstMatch(of: /(?i)^(?<book>.+?)\s+(?<ch>\d+):(?<vs>\d+)$/) {
        let book = try resolveBook(String(m.book))
        let ch = Int(m.ch)!
        let vs = Int(m.vs)!
        return BibleReference(book: book, chapterStart: ch, chapterEnd: ch,
                              verseStart: vs, verseEnd: vs)
    }

    // Pattern 4: Book Ch-Ch  (chapter range)
    if let m = ref.firstMatch(of: /(?i)^(?<book>.+?)\s+(?<cs>\d+)\s*[-–]\s*(?<ce>\d+)$/) {
        let book = try resolveBook(String(m.book))
        return BibleReference(book: book,
                              chapterStart: Int(m.cs)!, chapterEnd: Int(m.ce)!,
                              verseStart: nil, verseEnd: nil)
    }

    // Pattern 5: Book Ch  (single chapter, or verse in single-chapter book)
    if let m = ref.firstMatch(of: /(?i)^(?<book>.+?)\s+(?<ch>\d+)$/) {
        let book = try resolveBook(String(m.book))
        let num = Int(m.ch)!
        if _singleChapterBooks.contains(book) {
            return BibleReference(book: book, chapterStart: 1, chapterEnd: 1,
                                  verseStart: num, verseEnd: num)
        }
        return BibleReference(book: book, chapterStart: num, chapterEnd: num,
                              verseStart: nil, verseEnd: nil)
    }

    // Pattern 6: Book only
    let book = try resolveBook(ref)
    let chapterCount = _verseCountData[book]?.count ?? 1
    return BibleReference(book: book, chapterStart: 1, chapterEnd: chapterCount,
                          verseStart: nil, verseEnd: nil)
}

private func resolveBook(_ raw: String) throws -> String {
    let key = raw.trimmingCharacters(in: .whitespaces).lowercased()
    guard let canonical = _canonical[key] else {
        throw ParseError.unknownBook(raw)
    }
    return canonical
}

// MARK: - Internal helpers (used by BibleSpeechNormalizer)

/// Resolve a lowercased alias to its canonical book name, or nil if unknown.
func canonicalBookName(_ raw: String) -> String? {
    _canonical[raw.trimmingCharacters(in: .whitespaces).lowercased()]
}

/// Return the per-chapter verse counts for a canonical book name.
func verseCountsForBook(_ book: String) -> [Int]? {
    _verseCountData[book]
}

// MARK: - AnyCodable helper (for book_aliases.json mixed types)

private struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode([String].self) { value = v; return }
        if let v = try? c.decode([String: String].self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        value = ""
    }
}
