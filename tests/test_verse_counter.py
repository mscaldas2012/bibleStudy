import pytest
from bible_study.parser import parse
from bible_study.verse_counter import count_verses, is_short


def test_single_verse():
    assert count_verses(parse("John 3:16")) == 1


def test_verse_range_same_chapter():
    assert count_verses(parse("Matthew 5:3-12")) == 10


def test_whole_chapter_psalm_23():
    # Psalm 23 has 6 verses
    assert count_verses(parse("Psalm 23")) == 6


def test_chapter_range_genesis_1_3():
    # Gen 1: 31, Gen 2: 25, Gen 3: 24 = 80
    assert count_verses(parse("Genesis 1-3")) == 80


def test_philippians_4_6_7():
    assert count_verses(parse("Philippians 4:6-7")) == 2


def test_romans_8():
    # Romans 8 has 39 verses
    assert count_verses(parse("Romans 8")) == 39


def test_john_3_16():
    assert count_verses(parse("John 3:16")) == 1


def test_is_short_true():
    assert is_short(parse("John 3:16")) is True
    assert is_short(parse("Philippians 4:6-7")) is True
    assert is_short(parse("Romans 8:28-30")) is True  # 3 verses


def test_is_short_false():
    assert is_short(parse("Matthew 5:3-12")) is False
    assert is_short(parse("Psalm 23")) is False
    assert is_short(parse("Romans 8")) is False


def test_cross_chapter_range():
    # John 3:36 to John 4:3
    ref = parse("John 3:1-4:5")
    # John 3 has 36 verses: from v1 to v36 = 36 verses
    # Plus 5 verses of John 4
    assert count_verses(ref) == 36 + 5


def test_entire_book_philemon():
    # Philemon has 1 chapter, 25 verses
    ref = parse("Philemon")
    assert count_verses(ref) == 25
