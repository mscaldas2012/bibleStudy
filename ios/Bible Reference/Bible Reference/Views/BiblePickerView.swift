/// BiblePickerView.swift
/// 3-step Bible reference picker: Book → Chapter → Verse range.
/// Presented as a sheet from SidebarView.

import SwiftUI

// MARK: - Root sheet

struct BiblePickerView: View {
    @Environment(StudyViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// Navigation path: [BibleBook] (chapter step), [BibleBook, Int] (verse step)
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            BookPickerStep(path: $path)
                .navigationDestination(for: BibleBook.self) { book in
                    ChapterPickerStep(book: book, path: $path)
                }
                .navigationDestination(for: ChapterSelection.self) { sel in
                    VersePickerStep(selection: sel) { reference in
                        viewModel.referenceInput = reference
                        dismiss()
                        Task { await viewModel.submit() }
                    }
                }
        }
    }
}

// MARK: - Navigation value wrappers

struct ChapterSelection: Hashable {
    let book: BibleBook
    let chapter: Int   // 1-based

    func hash(into hasher: inout Hasher) {
        hasher.combine(book.id)
        hasher.combine(chapter)
    }

    static func == (lhs: ChapterSelection, rhs: ChapterSelection) -> Bool {
        lhs.book.id == rhs.book.id && lhs.chapter == rhs.chapter
    }
}

// MARK: - Step 1: Book picker

private struct BookPickerStep: View {
    @Binding var path: NavigationPath

    private let otSections: [BibleSection] = [.torah, .otHistory, .wisdom, .majorProphets, .minorProphets]
    private let ntSections: [BibleSection] = [.gospels, .ntHistory, .pauline, .generalLetters, .prophecy]

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            TestamentColumn(label: "Old Testament", sections: otSections, path: $path)
            TestamentColumn(label: "New Testament", sections: ntSections, path: $path)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)

        Group {
            if isIPad {
                // iPad: no ScrollView — sheet auto-sizes to content via .presentationSizing(.fitted)
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                ScrollView { content }
            }
        }
        .navigationTitle("Select Book")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TestamentColumn: View {
    let label: String
    let sections: [BibleSection]
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .padding(.bottom, 1)

            ForEach(sections) { section in
                SectionRow(section: section, path: $path)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct SectionRow: View {
    let section: BibleSection
    @Binding var path: NavigationPath

    var body: some View {
        let books = BibleCanon.books(in: section)
        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: 5),
            count: section.pickerColumns
        )

        VStack(alignment: .leading, spacing: 3) {
            Text(section.rawValue)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 4) {
                ForEach(books) { book in
                    Button {
                        path.append(book)
                    } label: {
                        Text(book.abbreviation)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Step 2: Chapter picker

private struct ChapterPickerStep: View {
    let book: BibleBook
    @Binding var path: NavigationPath

    private let columns = Array(repeating: GridItem(.adaptive(minimum: 52, maximum: 70), spacing: 10), count: 1)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 70), spacing: 10)], spacing: 10) {
                ForEach(1...book.chapterCount, id: \.self) { chapter in
                    Button("\(chapter)") {
                        path.append(ChapterSelection(book: book, chapter: chapter))
                    }
                    .font(.body.bold())
                    .frame(minWidth: 52, minHeight: 44)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding()
        }
        .navigationTitle("\(book.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Step 3: Verse range picker

private struct VersePickerStep: View {
    let selection: ChapterSelection
    let onConfirm: (String) -> Void

    @State private var startVerse: Int? = nil
    @State private var endVerse: Int? = nil

    private var verseCount: Int {
        let counts = selection.book.chapterVerseCounts
        let idx = selection.chapter - 1
        return idx < counts.count ? counts[idx] : 1
    }

    private var referenceString: String {
        guard let start = startVerse else { return "" }
        let end = endVerse ?? start
        let lo = min(start, end)
        let hi = max(start, end)
        let chap = selection.chapter
        let bookName = selection.book.name
        if lo == hi {
            return "\(bookName) \(chap):\(lo)"
        } else {
            return "\(bookName) \(chap):\(lo)-\(hi)"
        }
    }

    private var confirmLabel: String {
        referenceString.isEmpty ? "Select a verse" : referenceString
    }

    var body: some View {
        VStack(spacing: 0) {
            // Instruction banner
            VStack(spacing: 4) {
                Text(startVerse == nil
                     ? "Tap a verse to start"
                     : endVerse == nil
                        ? "Tap again to set end (or confirm single verse)"
                        : referenceString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .animation(.default, value: startVerse)
                    .animation(.default, value: endVerse)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 70), spacing: 10)], spacing: 10) {
                    ForEach(1...verseCount, id: \.self) { verse in
                        VerseCell(
                            verse: verse,
                            startVerse: startVerse,
                            endVerse: endVerse
                        ) {
                            handleTap(verse: verse)
                        }
                    }
                }
                .padding()
            }

            // Confirm button
            Button {
                guard !referenceString.isEmpty else { return }
                onConfirm(referenceString)
            } label: {
                Text(confirmLabel)
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(startVerse == nil)
            .padding()
        }
        .navigationTitle("Ch. \(selection.chapter)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset") {
                    startVerse = nil
                    endVerse = nil
                }
                .disabled(startVerse == nil)
            }
        }
    }

    private func handleTap(verse: Int) {
        if startVerse == nil {
            // First tap — set start
            startVerse = verse
            endVerse = nil
        } else if endVerse == nil {
            // Second tap — set end (allows re-tapping start to reset)
            if verse == startVerse {
                // Tapped same verse again: treat as confirm single verse
                endVerse = verse
            } else {
                endVerse = verse
            }
        } else {
            // Third tap — reset and start over from this verse
            startVerse = verse
            endVerse = nil
        }
    }
}

private struct VerseCell: View {
    let verse: Int
    let startVerse: Int?
    let endVerse: Int?
    let onTap: () -> Void

    private var isSelected: Bool {
        guard let start = startVerse else { return false }
        let end = endVerse ?? start
        let lo = min(start, end)
        let hi = max(start, end)
        return verse >= lo && verse <= hi
    }

    private var isEndpoint: Bool {
        guard let start = startVerse else { return false }
        let end = endVerse ?? start
        return verse == min(start, end) || verse == max(start, end)
    }

    var body: some View {
        Button(action: onTap) {
            Text("\(verse)")
                .font(.body.bold())
                .frame(minWidth: 52, minHeight: 44)
                .background(
                    isEndpoint
                        ? Color.accentColor
                        : isSelected
                            ? Color.accentColor.opacity(0.35)
                            : Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(isEndpoint ? .white : Color.accentColor)
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isEndpoint)
    }
}
