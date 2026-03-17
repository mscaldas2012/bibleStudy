"""
Bible reference parser.

Handles inputs like:
  "John 3:16"
  "Mt 5:3-12"
  "Psalm 23"
  "Gen 1-3"
  "Romans 8:28-39"
  "Philippians 4:6-7"
  "Philemon"  (single-chapter books)
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

_DATA_DIR = Path(__file__).parent.parent / "data"

with (_DATA_DIR / "book_aliases.json").open() as _f:
    _ALIAS_DATA = json.load(_f)

# Build lookup: lowercase input -> canonical book name
_CANONICAL: dict[str, str] = {}
for _book in _ALIAS_DATA["canonical"]:
    _CANONICAL[_book.lower()] = _book
for _alias, _canon in _ALIAS_DATA["aliases"].items():
    _CANONICAL[_alias.lower()] = _canon

# Books that have only one chapter (Obadiah, Philemon, 2 John, 3 John, Jude)
_SINGLE_CHAPTER_BOOKS = {"Obadiah", "Philemon", "2 John", "3 John", "Jude"}


@dataclass
class BibleRef:
    book: str
    chapter_start: int
    chapter_end: int
    verse_start: int | None  # None means "whole chapter"
    verse_end: int | None    # None means "to end of chapter_end"

    def __str__(self) -> str:
        if self.chapter_start == self.chapter_end:
            if self.verse_start is None:
                return f"{self.book} {self.chapter_start}"
            if self.verse_start == self.verse_end:
                return f"{self.book} {self.chapter_start}:{self.verse_start}"
            return f"{self.book} {self.chapter_start}:{self.verse_start}-{self.verse_end}"
        # multi-chapter
        if self.verse_start is None:
            return f"{self.book} {self.chapter_start}-{self.chapter_end}"
        return f"{self.book} {self.chapter_start}:{self.verse_start}-{self.chapter_end}:{self.verse_end}"

    def esv_query(self) -> str:
        """Format suitable for the ESV API `q` parameter."""
        return str(self)


class ParseError(ValueError):
    pass


# Patterns (most specific first)
# Pattern 1: Book Ch:V-Ch:V  (cross-chapter verse range)
_P_CROSS = re.compile(
    r"^(?P<book>.+?)\s+(?P<cs>\d+):(?P<vs>\d+)\s*[-–]\s*(?P<ce>\d+):(?P<ve>\d+)$",
    re.IGNORECASE,
)
# Pattern 2: Book Ch:V-V  (same-chapter verse range)
_P_VERSE_RANGE = re.compile(
    r"^(?P<book>.+?)\s+(?P<ch>\d+):(?P<vs>\d+)\s*[-–]\s*(?P<ve>\d+)$",
    re.IGNORECASE,
)
# Pattern 3: Book Ch:V  (single verse)
_P_SINGLE_VERSE = re.compile(
    r"^(?P<book>.+?)\s+(?P<ch>\d+):(?P<vs>\d+)$",
    re.IGNORECASE,
)
# Pattern 4: Book Ch-Ch  (chapter range)
_P_CHAP_RANGE = re.compile(
    r"^(?P<book>.+?)\s+(?P<cs>\d+)\s*[-–]\s*(?P<ce>\d+)$",
    re.IGNORECASE,
)
# Pattern 5: Book Ch  (single chapter)
_P_CHAP = re.compile(
    r"^(?P<book>.+?)\s+(?P<ch>\d+)$",
    re.IGNORECASE,
)
# Pattern 6: Book only (single-chapter books)
_P_BOOK_ONLY = re.compile(r"^(?P<book>.+?)$", re.IGNORECASE)


def _resolve_book(raw: str) -> str:
    key = raw.strip().lower()
    if key in _CANONICAL:
        return _CANONICAL[key]
    raise ParseError(f"Unknown book: '{raw}'")


def parse(reference: str) -> BibleRef:
    """Parse a Bible reference string into a BibleRef."""
    ref = reference.strip()

    m = _P_CROSS.match(ref)
    if m:
        book = _resolve_book(m.group("book"))
        return BibleRef(
            book=book,
            chapter_start=int(m.group("cs")),
            chapter_end=int(m.group("ce")),
            verse_start=int(m.group("vs")),
            verse_end=int(m.group("ve")),
        )

    m = _P_VERSE_RANGE.match(ref)
    if m:
        book = _resolve_book(m.group("book"))
        ch = int(m.group("ch"))
        return BibleRef(
            book=book,
            chapter_start=ch,
            chapter_end=ch,
            verse_start=int(m.group("vs")),
            verse_end=int(m.group("ve")),
        )

    m = _P_SINGLE_VERSE.match(ref)
    if m:
        book = _resolve_book(m.group("book"))
        ch = int(m.group("ch"))
        vs = int(m.group("vs"))
        return BibleRef(
            book=book,
            chapter_start=ch,
            chapter_end=ch,
            verse_start=vs,
            verse_end=vs,
        )

    m = _P_CHAP_RANGE.match(ref)
    if m:
        book = _resolve_book(m.group("book"))
        return BibleRef(
            book=book,
            chapter_start=int(m.group("cs")),
            chapter_end=int(m.group("ce")),
            verse_start=None,
            verse_end=None,
        )

    m = _P_CHAP.match(ref)
    if m:
        book = _resolve_book(m.group("book"))
        if book in _SINGLE_CHAPTER_BOOKS:
            # "Philemon 4" means verse 4 in the only chapter
            return BibleRef(
                book=book,
                chapter_start=1,
                chapter_end=1,
                verse_start=int(m.group("ch")),
                verse_end=int(m.group("ch")),
            )
        return BibleRef(
            book=book,
            chapter_start=int(m.group("ch")),
            chapter_end=int(m.group("ch")),
            verse_start=None,
            verse_end=None,
        )

    m = _P_BOOK_ONLY.match(ref)
    if m:
        book = _resolve_book(m.group("book"))
        return BibleRef(
            book=book,
            chapter_start=1,
            chapter_end=_chapter_count(book),
            verse_start=None,
            verse_end=None,
        )

    raise ParseError(f"Cannot parse reference: '{reference}'")


def _chapter_count(book: str) -> int:
    """Return number of chapters in a book (requires verse_counts loaded)."""
    from bible_study.verse_counter import VERSE_COUNTS
    return len(VERSE_COUNTS[book])
