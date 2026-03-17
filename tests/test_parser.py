import pytest
from bible_study.parser import parse, ParseError, BibleRef


def test_single_verse():
    ref = parse("John 3:16")
    assert ref.book == "John"
    assert ref.chapter_start == 3
    assert ref.verse_start == 16
    assert ref.verse_end == 16


def test_verse_range():
    ref = parse("Matthew 5:3-12")
    assert ref.book == "Matthew"
    assert ref.chapter_start == 5
    assert ref.verse_start == 3
    assert ref.verse_end == 12


def test_full_chapter():
    ref = parse("Psalm 23")
    assert ref.book == "Psalms"
    assert ref.chapter_start == 23
    assert ref.verse_start is None


def test_chapter_range():
    ref = parse("Genesis 1-3")
    assert ref.book == "Genesis"
    assert ref.chapter_start == 1
    assert ref.chapter_end == 3
    assert ref.verse_start is None


def test_cross_chapter_verse_range():
    ref = parse("John 3:1-4:5")
    assert ref.book == "John"
    assert ref.chapter_start == 3
    assert ref.chapter_end == 4
    assert ref.verse_start == 1
    assert ref.verse_end == 5


def test_abbreviations():
    assert parse("Jn 3:16").book == "John"
    assert parse("Mt 5:1").book == "Matthew"
    assert parse("Ps 23").book == "Psalms"
    assert parse("Gen 1").book == "Genesis"
    assert parse("Rom 8:28").book == "Romans"
    assert parse("Phil 4:6").book == "Philippians"
    assert parse("1 Cor 13").book == "1 Corinthians"
    assert parse("Rev 21:1").book == "Revelation"


def test_case_insensitive():
    assert parse("john 3:16").book == "John"
    assert parse("GENESIS 1:1").book == "Genesis"


def test_single_chapter_book_verse():
    ref = parse("Philemon 10")
    assert ref.book == "Philemon"
    assert ref.chapter_start == 1
    assert ref.verse_start == 10


def test_single_chapter_book_whole():
    ref = parse("Jude")
    assert ref.book == "Jude"
    assert ref.chapter_start == 1
    assert ref.verse_start is None


def test_str_output_single_verse():
    ref = parse("Romans 8:28")
    assert str(ref) == "Romans 8:28"


def test_str_output_range():
    ref = parse("Matthew 5:3-12")
    assert str(ref) == "Matthew 5:3-12"


def test_str_output_chapter():
    ref = parse("Psalm 23")
    assert str(ref) == "Psalms 23"


def test_unknown_book():
    with pytest.raises(ParseError):
        parse("Hezekiah 3:16")


def test_romans_8_28():
    ref = parse("Romans 8:28")
    assert ref.book == "Romans"
    assert ref.chapter_start == 8
    assert ref.verse_start == 28
    assert ref.verse_end == 28
