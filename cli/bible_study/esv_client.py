"""
ESV API client.

Fetches Bible passage text from api.esv.org.
Only called for passages of 5 verses or fewer.
"""

from __future__ import annotations

import os

import requests

from bible_study.parser import BibleRef

ESV_API_URL = "https://api.esv.org/v3/passage/text/"

_DEFAULT_PARAMS = {
    "include-headings": "false",
    "include-footnotes": "false",
    "include-passage-references": "false",
    "include-short-copyright": "false",
    "include-copyright": "false",
}


class ESVClientError(RuntimeError):
    pass


def get_passage(ref: BibleRef, api_key: str | None = None) -> str:
    """
    Fetch the ESV text for the given BibleRef.

    Returns the passage text as a plain string.
    Raises ESVClientError on API failures.
    """
    key = api_key or os.environ.get("ESV_API_KEY")
    if not key:
        raise ESVClientError(
            "ESV API key not found. Set ESV_API_KEY in your environment or .env file."
        )

    params = {**_DEFAULT_PARAMS, "q": ref.esv_query()}
    headers = {"Authorization": f"Token {key}"}

    try:
        response = requests.get(ESV_API_URL, params=params, headers=headers, timeout=10)
    except requests.RequestException as exc:
        raise ESVClientError(f"Network error fetching ESV passage: {exc}") from exc

    if response.status_code == 401:
        raise ESVClientError("Invalid ESV API key (401 Unauthorized).")
    if response.status_code != 200:
        raise ESVClientError(
            f"ESV API returned {response.status_code}: {response.text[:200]}"
        )

    data = response.json()
    passages = data.get("passages", [])
    if not passages:
        raise ESVClientError(f"ESV API returned no passages for: {ref}")

    return passages[0].strip()
