/* Speech recognition disabled — entire file commented out.

/// BibleLanguageModelService.swift
/// Prepares and caches a custom SFSpeechRecognizer language model tuned for Bible references.
/// Requires iOS 17+. Gracefully degrades on older OS versions.
///
/// Preparation flow (runs once, results cached on disk):
///   1. Build SFCustomLanguageModelData with pronunciations + phrase templates
///   2. Export raw data to a temp .bin via data.export(to:)
///   3. Compile with SFSpeechLanguageModel.prepareCustomLanguageModel(for:clientIdentifier:configuration:)
///   4. Cache the compiled model directory; reuse on subsequent launches
///
/// The phrase templates use word-number token classes ("three", "sixteen") so the
/// recognizer emits separate word tokens instead of collapsing them into "316".

import Foundation
import Speech
import OSLog

private let logger = Logger(subsystem: "com.bibleStudy", category: "LanguageModel")

@available(iOS 17, *)
actor BibleLanguageModelService {

    static let shared = BibleLanguageModelService()
    private init() {}

    /// URL to the compiled model directory, set after successful preparation.
    private(set) var compiledModelURL: URL?

    /// Prepare the model if not already cached. Safe to call multiple times.
    func prepare() async {
        guard compiledModelURL == nil else { return }

        let modelDir = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BibleSpeechModel", isDirectory: true)

        // Reuse a previously compiled model if it exists on disk.
        if FileManager.default.fileExists(atPath: modelDir.path) {
            compiledModelURL = modelDir
            logger.info("Reusing cached Bible language model at \(modelDir.path)")
            return
        }

        // Export raw training data to a temporary .bin file.
        let tempBin = FileManager.default.temporaryDirectory
            .appendingPathComponent("BibleModelData_\(UUID().uuidString).bin")

        do {
            let data = buildModelData()
            try await data.export(to: tempBin)

            // Compile the model into the cache directory.
            let config = SFSpeechLanguageModel.Configuration(languageModel: modelDir)
            let clientID = Bundle.main.bundleIdentifier ?? "com.bibleStudy"
            try await SFSpeechLanguageModel.prepareCustomLanguageModel(
                for: tempBin,
                clientIdentifier: clientID,
                configuration: config
            )

            compiledModelURL = modelDir
            logger.info("Bible language model prepared successfully")
        } catch {
            logger.error("Failed to prepare Bible language model: \(error)")
            // Clean up so the next launch retries from scratch.
            try? FileManager.default.removeItem(at: modelDir)
        }

        try? FileManager.default.removeItem(at: tempBin)
    }

    // MARK: - Model construction

    private func buildModelData() -> SFCustomLanguageModelData {
        SFCustomLanguageModelData(
            locale: Locale(identifier: "en-US"),
            identifier: "com.bibleStudy.bibleReference",
            version: "1"
        ) {
            // ── Custom pronunciations for hard book names ──────────────────
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Habakkuk",      phonemes: ["h@'bAkUk"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Deuteronomy",   phonemes: ["djut@'rQn@mi"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Ecclesiastes",  phonemes: ["Ikli:zi'Asti:z"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Thessalonians", phonemes: ["TEs@'l@UniEnz"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Philippians",   phonemes: ["fI'lIpiEnz"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Philemon",      phonemes: ["fI'li:m@n"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Nehemiah",      phonemes: ["ni:@'maI@"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Zechariah",     phonemes: ["zEk@'raI@"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Zephaniah",     phonemes: ["zEf@'naI@"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Obadiah",       phonemes: ["@Ub@'daI@"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Nahum",         phonemes: ["'neIh@m"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Haggai",        phonemes: ["'hAgaI"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Malachi",       phonemes: ["'mAl@kaI"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Galatians",     phonemes: ["g@'leISEnz"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Colossians",    phonemes: ["k@'lQSEnz"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Lamentations",  phonemes: ["lAm@n'teISEnz"])
            SFCustomLanguageModelData.CustomPronunciation(grapheme: "Leviticus",     phonemes: ["l@'vItIk@s"])

            // ── Template phrases ───────────────────────────────────────────
            // Word-number classes keep chapter and verse as distinct spoken tokens,
            // preventing the recognizer from collapsing "three sixteen" into "316".
            SFCustomLanguageModelData.PhraseCountsFromTemplates(
                classes: [
                    "book":    Self.allBookNames,
                    "chapter": Self.chapterWords,
                    "verse":   Self.verseWords,
                ]
            ) {
                // Bare reference patterns
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "<book> <chapter>", count: 500)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "<book> <chapter> <verse>", count: 1000)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "<book> <chapter> <verse> to <verse>", count: 500)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "<book> <chapter> <verse> through <verse>", count: 500)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "<book> <chapter> to <chapter>", count: 300)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "<book> <chapter> through <chapter>", count: 300)
                // Spoken-prefix variants
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "turn to <book> <chapter> <verse>", count: 200)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "read <book> <chapter> <verse>", count: 200)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template(
                    "open to <book> <chapter> <verse>", count: 200)
            }
        }
    }

    // MARK: - Book name list

    /// All 66 canonical names plus spoken ordinal forms for numbered books.
    private static let allBookNames: [String] = {
        var names: [String] = [
            // Old Testament
            "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
            "Joshua", "Judges", "Ruth",
            "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
            "1 Chronicles", "2 Chronicles",
            "Ezra", "Nehemiah", "Esther", "Job", "Psalms",
            "Proverbs", "Ecclesiastes", "Song of Solomon",
            "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
            "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
            "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
            // New Testament
            "Matthew", "Mark", "Luke", "John", "Acts",
            "Romans", "1 Corinthians", "2 Corinthians",
            "Galatians", "Ephesians", "Philippians", "Colossians",
            "1 Thessalonians", "2 Thessalonians",
            "1 Timothy", "2 Timothy", "Titus", "Philemon",
            "Hebrews", "James",
            "1 Peter", "2 Peter",
            "1 John", "2 John", "3 John",
            "Jude", "Revelation",
        ]
        // Add spoken ordinal forms so the model covers "First Samuel" etc.
        let ordinalPairs: [(String, String)] = [
            ("1 Samuel", "First Samuel"),  ("2 Samuel", "Second Samuel"),
            ("1 Kings", "First Kings"),    ("2 Kings", "Second Kings"),
            ("1 Chronicles", "First Chronicles"), ("2 Chronicles", "Second Chronicles"),
            ("1 Corinthians", "First Corinthians"), ("2 Corinthians", "Second Corinthians"),
            ("1 Thessalonians", "First Thessalonians"), ("2 Thessalonians", "Second Thessalonians"),
            ("1 Timothy", "First Timothy"), ("2 Timothy", "Second Timothy"),
            ("1 Peter", "First Peter"),    ("2 Peter", "Second Peter"),
            ("1 John", "First John"),      ("2 John", "Second John"), ("3 John", "Third John"),
        ]
        names += ordinalPairs.map(\.1)
        return names
    }()

    // MARK: - Number word lists

    private static let chapterWords: [String] = numberWords(through: 150)
    private static let verseWords: [String]   = numberWords(through: 176)

    private static func numberWords(through max: Int) -> [String] {
        let ones  = ["one","two","three","four","five","six","seven","eight","nine",
                     "ten","eleven","twelve","thirteen","fourteen","fifteen","sixteen",
                     "seventeen","eighteen","nineteen"]
        let tensW = ["twenty","thirty","forty","fifty","sixty","seventy","eighty","ninety"]

        func word(_ n: Int) -> String {
            if n >= 1 && n <= 19 { return ones[n - 1] }
            if n == 100 { return "one hundred" }
            if n >= 20 && n <= 99 {
                let t = (n / 10) - 2; let o = n % 10
                return o == 0 ? tensW[t] : "\(tensW[t]) \(ones[o - 1])"
            }
            if n >= 101 { return "one hundred \(word(n - 100))" }
            return "\(n)"
        }

        return (1...max).map { word($0) }
    }
}

*/ // end Speech recognition disabled
