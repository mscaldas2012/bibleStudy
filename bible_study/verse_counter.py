"""
Verse counting logic using bundled static data.

Given a BibleRef, returns the total number of verses it spans.
"""

from __future__ import annotations

import json
from pathlib import Path

from bible_study.parser import BibleRef

_DATA_DIR = Path(__file__).parent.parent / "data"

with (_DATA_DIR / "verse_counts.json").open() as _f:
    VERSE_COUNTS: dict[str, list[int]] = json.load(_f)


def count_verses(ref: BibleRef) -> int:
    """Return the number of verses in the given BibleRef."""
    book_data = VERSE_COUNTS.get(ref.book)
    if book_data is None:
        raise ValueError(f"No verse count data for book: {ref.book}")

    cs = ref.chapter_start - 1  # 0-indexed
    ce = ref.chapter_end - 1

    if cs < 0 or ce >= len(book_data):
        raise ValueError(
            f"Chapter out of range for {ref.book}: "
            f"chapters {ref.chapter_start}-{ref.chapter_end} "
            f"(book has {len(book_data)} chapters)"
        )

    # Whole-chapter references
    if ref.verse_start is None:
        return sum(book_data[cs : ce + 1])

    # Verse references within same chapter
    if cs == ce:
        total_in_chapter = book_data[cs]
        vs = ref.verse_start
        ve = ref.verse_end if ref.verse_end is not None else total_in_chapter
        if vs > total_in_chapter or ve > total_in_chapter:
            raise ValueError(
                f"{ref.book} {ref.chapter_start} only has {total_in_chapter} verses"
            )
        return ve - vs + 1

    # Cross-chapter verse range (e.g. John 3:1 - 4:5)
    total_in_start = book_data[cs]
    vs = ref.verse_start
    ve = ref.verse_end if ref.verse_end is not None else book_data[ce]

    # Verses in first chapter
    count = total_in_start - vs + 1
    # Middle chapters (whole chapters)
    for ch_idx in range(cs + 1, ce):
        count += book_data[ch_idx]
    # Verses in last chapter
    count += ve

    return count


def is_short(ref: BibleRef, threshold: int = 5) -> bool:
    """Return True if the reference spans <= threshold verses."""
    return count_verses(ref) <= threshold
