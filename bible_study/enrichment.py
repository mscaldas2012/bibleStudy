"""
Enrichment orchestrator.

Wires together: parser → verse counter → ESV client → LLM → StudyNote
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from bible_study.esv_client import get_passage, ESVClientError
from bible_study.parser import BibleRef, parse
from bible_study.prompts import SYSTEM_PROMPT, build_user_message
from bible_study.providers import LLMProvider, get_provider
from bible_study.verse_counter import is_short


@dataclass
class CrossRef:
    reference: str
    connection: str


@dataclass
class StudyNote:
    reference: str
    bible_text: str | None  # None when passage is too long
    main_topic: str
    context: str
    historical_cultural: str
    cross_references: list[CrossRef] = field(default_factory=list)
    applications: list[str] = field(default_factory=list)


class EnrichmentError(RuntimeError):
    pass


def enrich(
    reference_str: str,
    provider: LLMProvider | None = None,
    esv_api_key: str | None = None,
    verse_threshold: int = 5,
) -> StudyNote:
    """
    Parse a Bible reference and return a StudyNote with enrichment.

    Args:
        reference_str: Raw reference like "John 3:16" or "Psalm 23"
        provider: LLMProvider instance; defaults to env-configured provider
        esv_api_key: Override for ESV_API_KEY env var
        verse_threshold: Passages with this many verses or fewer get full text
    """
    ref: BibleRef = parse(reference_str)

    # Fetch ESV text only for short passages
    bible_text: str | None = None
    if is_short(ref, threshold=verse_threshold):
        bible_text = get_passage(ref, api_key=esv_api_key)

    llm = provider or get_provider()
    user_message = build_user_message(str(ref), bible_text)

    raw_response = llm.generate(system=SYSTEM_PROMPT, user=user_message)
    note = _parse_response(raw_response, str(ref), bible_text)
    return note


def _extract_json(text: str) -> str:
    """Extract JSON object from a string that may contain extra prose."""
    # Replace curly/smart quotes (common in LLM output) with straight single quotes
    # so they don't break JSON parsing. These appear as quotation marks within
    # string values, not as JSON structural characters.
    text = text.replace("\u201c", "'").replace("\u201d", "'")
    # Also replace other common problematic unicode quotes
    text = text.replace("\u2018", "'").replace("\u2019", "'")

    # Try to find a JSON block
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        return match.group(0)
    return text


def _parse_response(raw: str, reference_str: str, bible_text: str | None) -> StudyNote:
    """Parse the LLM JSON response into a StudyNote."""
    json_str = _extract_json(raw)

    # Try strict parse first; fall back to json-repair for models that produce
    # unescaped quotes, truncated output, or other common malformations.
    try:
        data = json.loads(json_str)
    except json.JSONDecodeError:
        try:
            from json_repair import repair_json
            data = repair_json(json_str, return_objects=True)
            if not isinstance(data, dict):
                raise ValueError("json_repair did not return a dict")
        except Exception as exc:
            raise EnrichmentError(
                f"LLM returned invalid JSON that could not be repaired.\n"
                f"Error: {exc}\n"
                f"Raw response:\n{raw[:500]}"
            ) from exc

    cross_refs = [
        CrossRef(
            reference=cr.get("reference", ""),
            connection=cr.get("connection", ""),
        )
        for cr in data.get("cross_references", [])
    ]

    return StudyNote(
        reference=data.get("reference", reference_str),
        bible_text=bible_text,
        main_topic=data.get("main_topic", ""),
        context=data.get("context", ""),
        historical_cultural=data.get("historical_cultural", ""),
        cross_references=cross_refs,
        applications=data.get("applications", []),
    )
