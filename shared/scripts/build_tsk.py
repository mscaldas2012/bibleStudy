#!/usr/bin/env python3
"""
build_tsk.py — Convert openbible.info cross-references.txt to tsk.sqlite.

Usage:
    python shared/scripts/build_tsk.py

Input:  cross_references.txt downloaded from:
        https://raw.githubusercontent.com/scrollmapper/bible_databases/master/sources/extras/cross_references.txt
        (place next to this script or pass --input path)

Output: shared/tsk.sqlite

The input uses dot-separated OSIS abbreviations (Gen.1.1).
We normalise them to canonical book names matching book_aliases.json.
"""

import argparse
import json
import re
import sqlite3
from pathlib import Path

# ---------------------------------------------------------------------------
# Book name normalisation — OSIS abbreviation → canonical name used in app
# ---------------------------------------------------------------------------

OSIS_TO_CANONICAL: dict[str, str] = {
    "Gen": "Genesis", "Exod": "Exodus", "Lev": "Leviticus", "Num": "Numbers",
    "Deut": "Deuteronomy", "Josh": "Joshua", "Judg": "Judges", "Ruth": "Ruth",
    "1Sam": "1 Samuel", "2Sam": "2 Samuel", "1Kgs": "1 Kings", "2Kgs": "2 Kings",
    "1Chr": "1 Chronicles", "2Chr": "2 Chronicles", "Ezra": "Ezra", "Neh": "Nehemiah",
    "Esth": "Esther", "Job": "Job", "Ps": "Psalms", "Prov": "Proverbs",
    "Eccl": "Ecclesiastes", "Song": "Song of Solomon", "Isa": "Isaiah",
    "Jer": "Jeremiah", "Lam": "Lamentations", "Ezek": "Ezekiel", "Dan": "Daniel",
    "Hos": "Hosea", "Joel": "Joel", "Amos": "Amos", "Obad": "Obadiah",
    "Jonah": "Jonah", "Mic": "Micah", "Nah": "Nahum", "Hab": "Habakkuk",
    "Zeph": "Zephaniah", "Hag": "Haggai", "Zech": "Zechariah", "Mal": "Malachi",
    "Matt": "Matthew", "Mark": "Mark", "Luke": "Luke", "John": "John",
    "Acts": "Acts", "Rom": "Romans", "1Cor": "1 Corinthians",
    "2Cor": "2 Corinthians", "Gal": "Galatians", "Eph": "Ephesians",
    "Phil": "Philippians", "Col": "Colossians", "1Thess": "1 Thessalonians",
    "2Thess": "2 Thessalonians", "1Tim": "1 Timothy", "2Tim": "2 Timothy",
    "Titus": "Titus", "Phlm": "Philemon", "Heb": "Hebrews", "Jas": "James",
    "1Pet": "1 Peter", "2Pet": "2 Peter", "1John": "1 John", "2John": "2 John",
    "3John": "3 John", "Jude": "Jude", "Rev": "Revelation",
}

# ---------------------------------------------------------------------------

def parse_verse_ref(raw: str) -> tuple[str, int, int, int] | None:
    """
    Parse 'Gen.1.1' or 'Prov.8.22-Prov.8.30' → (book, chapter, verse_start, verse_end).
    For ranges we take only the start verse of the target (to-verse).
    Returns None if the ref can't be parsed.
    """
    # Take only the first half of a range
    ref = raw.split("-")[0].strip()
    parts = ref.split(".")
    if len(parts) < 3:
        return None
    book_osis = parts[0]
    try:
        chapter = int(parts[1])
        verse = int(parts[2])
    except ValueError:
        return None
    canonical = OSIS_TO_CANONICAL.get(book_osis)
    if canonical is None:
        return None
    return canonical, chapter, verse, verse


def parse_to_ref_range(raw: str) -> tuple[str, int, int, int] | None:
    """
    Parse the to-verse field which may be a range 'Prov.8.22-Prov.8.30'.
    Returns (book, chapter, verse_start, verse_end).
    """
    if "-" in raw:
        start_raw, end_raw = raw.split("-", 1)
        start = parse_verse_ref(start_raw)
        end_parts = end_raw.strip().split(".")
        if start and len(end_parts) >= 3:
            try:
                verse_end = int(end_parts[2])
                return start[0], start[1], start[2], verse_end
            except ValueError:
                pass
        return start
    return parse_verse_ref(raw)


def main():
    parser = argparse.ArgumentParser(description="Convert TSK cross-references to SQLite")
    parser.add_argument("--input", default=Path(__file__).parent / "cross_references.txt",
                        help="Path to cross_references.txt (default: next to this script)")
    parser.add_argument("--output", default=Path(__file__).parent.parent / "tsk.sqlite",
                        help="Output SQLite path (default: shared/tsk.sqlite)")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"Input not found: {input_path}")
        print("Download it with:")
        print("  curl -sL https://raw.githubusercontent.com/scrollmapper/bible_databases/master/sources/extras/cross_references.txt -o shared/scripts/cross_references.txt")
        raise SystemExit(1)

    if output_path.exists():
        output_path.unlink()

    conn = sqlite3.connect(output_path)
    conn.execute("""
        CREATE TABLE cross_refs (
            from_book TEXT NOT NULL,
            from_chapter INTEGER NOT NULL,
            from_verse INTEGER NOT NULL,
            to_book TEXT NOT NULL,
            to_chapter INTEGER NOT NULL,
            to_verse_start INTEGER NOT NULL,
            to_verse_end INTEGER NOT NULL,
            votes INTEGER NOT NULL DEFAULT 0
        )
    """)
    conn.execute("CREATE INDEX idx_from ON cross_refs(from_book, from_chapter, from_verse)")

    rows = []
    skipped = 0

    with input_path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("From") or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            from_raw, to_raw = parts[0], parts[1]
            votes = int(parts[2]) if len(parts) >= 3 else 0

            from_ref = parse_verse_ref(from_raw)
            to_ref = parse_to_ref_range(to_raw)

            if from_ref is None or to_ref is None:
                skipped += 1
                continue

            rows.append((
                from_ref[0], from_ref[1], from_ref[2],   # from book/ch/v
                to_ref[0], to_ref[1], to_ref[2], to_ref[3],  # to book/ch/v_start/v_end
                votes,
            ))

            if len(rows) >= 10_000:
                conn.executemany(
                    "INSERT INTO cross_refs VALUES (?,?,?,?,?,?,?,?)", rows
                )
                rows.clear()

    if rows:
        conn.executemany("INSERT INTO cross_refs VALUES (?,?,?,?,?,?,?,?)", rows)

    conn.commit()
    count = conn.execute("SELECT COUNT(*) FROM cross_refs").fetchone()[0]
    conn.close()

    size_mb = output_path.stat().st_size / 1_048_576
    print(f"Done: {count:,} cross-references → {output_path} ({size_mb:.1f} MB), skipped {skipped}")


if __name__ == "__main__":
    main()
