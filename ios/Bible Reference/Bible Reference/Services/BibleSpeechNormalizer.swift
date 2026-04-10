/// BibleSpeechNormalizer.swift
/// Converts raw speech output to a parseable Bible reference string.
///
/// Handles two input forms:
///   • Word-number form  (custom LM path): "john three sixteen"  → "John 3:16"
///   • Collapsed-digit form (plain STT):   "John 316"            → "John 3:16"

import Foundation

enum BibleSpeechNormalizer {

    /// Attempt to normalize a speech transcript into a parseable Bible reference.
    /// Returns the original string unchanged if it already looks parseable or cannot be mapped.
    static func normalize(_ transcript: String) -> String {
        // Already looks like a typed reference — don't touch it.
        if looksAlreadyParseable(transcript) { return transcript }
        let lowered = transcript.lowercased().trimmingCharacters(in: .whitespaces)
        let stripped = stripPrefix(lowered)
        let ordinalFixed = replaceLeadingOrdinal(stripped)
        let corrected = correctFirstToken(ordinalFixed)
        if let result = tryParse(corrected) { return result }
        return transcript
    }

    // MARK: - Quick checks

    private static func looksAlreadyParseable(_ s: String) -> Bool {
        // Contains a colon (e.g. "John 3:16") or digit-hyphen-digit (e.g. "John 3-5")
        s.contains(":") || s.range(of: #"\d[-–]\d"#, options: .regularExpression) != nil
    }

    // MARK: - Prefix stripping

    private static let spokenPrefixes = [
        "turn to ", "open to ", "found in ", "go to ", "read ",
    ]

    private static func stripPrefix(_ s: String) -> String {
        for prefix in spokenPrefixes {
            if s.hasPrefix(prefix) { return String(s.dropFirst(prefix.count)) }
        }
        return s
    }

    // MARK: - Phonetic corrections (accent / homophones)

    /// Maps first-token misrecognitions to their correct lowercase form.
    /// Only the leading token is corrected so false positives are avoided —
    /// if the corrected token doesn't resolve to a real book + number suffix
    /// the normalizer falls through and returns the original transcript.
    private static let speechCorrections: [String: String] = [
        "look": "luke",   // "Luke" often heard as "look"
        "luk":  "luke",   // short-form misrecognition
        "book": "luke",   // "Luke" occasionally heard as "book"
    ]

    /// Applies `speechCorrections` to the first token of the (space-separated) string.
    private static func correctFirstToken(_ s: String) -> String {
        if let space = s.firstIndex(of: " ") {
            let first = String(s[..<space])
            if let fixed = speechCorrections[first] {
                return fixed + s[space...]
            }
        } else if let fixed = speechCorrections[s] {
            return fixed
        }
        return s
    }

    // MARK: - Ordinal → digit (for numbered books like "First Kings")

    private static let ordinalMap: [(String, String)] = [
        ("third ", "3 "), ("second ", "2 "), ("first ", "1 "),
    ]

    private static func replaceLeadingOrdinal(_ s: String) -> String {
        for (word, digit) in ordinalMap {
            if s.hasPrefix(word) { return digit + String(s.dropFirst(word.count)) }
        }
        return s
    }

    // MARK: - Main parse

    private static func tryParse(_ input: String) -> String? {
        let tokens = input.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return nil }

        // Find the longest prefix of tokens that resolves to a canonical book name.
        for len in stride(from: min(tokens.count, 5), through: 1, by: -1) {
            let candidate = tokens[0..<len].joined(separator: " ")
            guard let book = canonicalBookName(candidate) else { continue }
            let rest = Array(tokens[len...])
            guard !rest.isEmpty else { return book }
            return parseNumbersSuffix(book: book, tokens: rest[...])
        }
        return nil
    }

    // MARK: - Number suffix parsing

    /// Structural keywords the user may speak; strip them and use as position hints.
    private static let chapterKeywords: Set<String> = ["chapter", "chapters"]
    private static let verseKeywords:   Set<String> = ["verse", "verses", "v"]

    private static func parseNumbersSuffix(book: String, tokens: ArraySlice<String>) -> String? {
        var remaining = tokens

        // Check for a single collapsed digit string like "316"
        if remaining.count == 1, let n = Int(remaining.first!) {
            return resolveCollapsed(book: book, number: n)
        }

        // Strip optional "chapter" keyword before the chapter number.
        if let first = remaining.first, chapterKeywords.contains(first) {
            remaining = remaining.dropFirst()
        }

        // Consume first number (chapter or single number)
        guard let (chapter, afterChapter) = consumeNumber(from: remaining) else {
            return nil
        }
        remaining = afterChapter

        if remaining.isEmpty { return "\(book) \(chapter)" }

        // "to" / "through" after chapter → chapter range
        if remaining.first == "to" || remaining.first == "through" {
            remaining = remaining.dropFirst()
            // Skip optional "chapter" keyword before second chapter number
            if let t = remaining.first, chapterKeywords.contains(t) { remaining = remaining.dropFirst() }
            guard let (chapter2, _) = consumeNumber(from: remaining) else {
                return "\(book) \(chapter)"
            }
            return "\(book) \(chapter)-\(chapter2)"
        }

        // Strip optional "verse"/"verses" keyword — its presence confirms we're now
        // parsing a verse number rather than another chapter.
        if let t = remaining.first, verseKeywords.contains(t) {
            remaining = remaining.dropFirst()
        }

        // Second number group → verse
        guard let (verse, afterVerse) = consumeNumber(from: remaining) else {
            return "\(book) \(chapter)"
        }
        remaining = afterVerse

        if remaining.isEmpty { return "\(book) \(chapter):\(verse)" }

        // "to" / "through" after verse → verse range.
        // Also accept "two" as a stand-in for "to" here — but ONLY when followed by
        // another number. This handles accents where "to" is heard as "two":
        //   "Matthew six two two seven" → Matthew 6:2-7  (not 6:227)
        // We restrict this to the verse-range position (chapter already known) so that
        // "Matthew two two" still correctly parses as Matthew 2:2, not Matthew 2-2.
        if isVerseRangeSeparator(remaining) {
            remaining = remaining.dropFirst()
            // Skip optional "verse" keyword before end of range (e.g. "verse three to verse seven")
            if let t = remaining.first, verseKeywords.contains(t) { remaining = remaining.dropFirst() }
            guard let (verseEnd, _) = consumeNumber(from: remaining) else {
                return "\(book) \(chapter):\(verse)"
            }
            return "\(book) \(chapter):\(verse)-\(verseEnd)"
        }

        return "\(book) \(chapter):\(verse)"
    }

    /// Returns true when the front token should be treated as a verse-range separator.
    /// Accepts "to" and "through" unconditionally, and "two" only when the token that
    /// follows it is a number (distinguishing the separator "to" from the verse number 2).
    private static func isVerseRangeSeparator(_ tokens: ArraySlice<String>) -> Bool {
        guard let first = tokens.first else { return false }
        if first == "to" || first == "through" { return true }
        if first == "two" {
            // Peek at the next token — if it's a number, "two" is acting as "to".
            let afterTwo = tokens.dropFirst()
            return consumeNumber(from: afterTwo) != nil
        }
        return false
    }

    // MARK: - Collapsed number disambiguation

    /// Splits a raw digit like 316 into a valid chapter:verse for the given book.
    /// Tries all split positions, preferring the leftmost valid split.
    private static func resolveCollapsed(book: String, number: Int) -> String? {
        guard let bookData = verseCountsForBook(book) else { return nil }
        let s = String(number)
        for split in 1..<s.count {
            let chStr = String(s.prefix(split))
            let vsStr = String(s.suffix(s.count - split))
            guard let ch = Int(chStr), let vs = Int(vsStr),
                  ch >= 1, ch <= bookData.count,
                  vs >= 1, vs <= bookData[ch - 1] else { continue }
            return "\(book) \(ch):\(vs)"
        }
        // Maybe it's just a chapter number
        if number >= 1 && number <= bookData.count { return "\(book) \(number)" }
        return nil
    }

    // MARK: - Number word → Int

    private static let ones: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
        "nineteen": 19,
    ]

    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    /// Greedy consume of a spoken number from the front of the token slice.
    /// Returns (value, remaining) or nil if the front token is not a number word or digit.
    private static func consumeNumber(from tokens: ArraySlice<String>) -> (Int, ArraySlice<String>)? {
        guard let first = tokens.first else { return nil }

        // Raw digit
        if let n = Int(first) { return (n, tokens.dropFirst()) }

        // "one hundred [optional sub-hundred]"
        if first == "one" {
            let rest = tokens.dropFirst()
            if rest.first == "hundred" {
                let afterHundred = rest.dropFirst()
                if let (extra, afterExtra) = consumeSubHundred(from: afterHundred) {
                    return (100 + extra, afterExtra)
                }
                return (100, afterHundred)
            }
            return (1, rest)
        }

        // Tens word, optionally followed by a ones word
        if let tensVal = tens[first] {
            let rest = tokens.dropFirst()
            if let second = rest.first, let onesVal = ones[second] {
                return (tensVal + onesVal, rest.dropFirst())
            }
            return (tensVal, rest)
        }

        // Ones word (2–19; "one" handled above)
        if let onesVal = ones[first] { return (onesVal, tokens.dropFirst()) }

        return nil
    }

    private static func consumeSubHundred(from tokens: ArraySlice<String>) -> (Int, ArraySlice<String>)? {
        guard let first = tokens.first else { return nil }
        if let tensVal = tens[first] {
            let rest = tokens.dropFirst()
            if let second = rest.first, let onesVal = ones[second] {
                return (tensVal + onesVal, rest.dropFirst())
            }
            return (tensVal, rest)
        }
        if let onesVal = ones[first] { return (onesVal, tokens.dropFirst()) }
        return nil
    }
}
