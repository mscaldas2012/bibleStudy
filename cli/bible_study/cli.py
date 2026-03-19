"""
CLI entry point for the Bible study tool.

Usage:
    python -m bible_study.cli "John 3:16"
    python -m bible_study.cli --save "Romans 8:28"
    python -m bible_study.cli --provider claude "Psalm 23"
"""

from __future__ import annotations

import sys
from pathlib import Path

import click
from dotenv import load_dotenv

# Load .env from project root
_PROJECT_ROOT = Path(__file__).parent.parent
load_dotenv(_PROJECT_ROOT / ".env")


@click.command()
@click.argument("reference")
@click.option(
    "--save",
    is_flag=True,
    default=False,
    help="Save the study note as a markdown file in notes/",
)
@click.option(
    "--provider",
    default=None,
    type=click.Choice(["mlx", "claude"], case_sensitive=False),
    help="LLM provider to use (overrides BIBLE_LLM_PROVIDER env var)",
)
@click.option(
    "--no-notify",
    is_flag=True,
    default=False,
    help="Skip macOS notification",
)
def main(reference: str, save: bool, provider: str | None, no_notify: bool) -> None:
    """Look up a Bible reference and generate a study note.

    REFERENCE can be a verse, range, chapter, or book, e.g.:

    \b
        bs "John 3:16"
        bs "Matthew 5:3-12"
        bs "Psalm 23"
        bs "Genesis 1-3"
    """
    from bible_study.enrichment import enrich, EnrichmentError
    from bible_study.output import render_terminal, send_notification, save_markdown
    from bible_study.providers import get_provider

    try:
        llm_provider = get_provider(provider) if provider else None
        note = enrich(reference, provider=llm_provider)
    except EnrichmentError as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)
    except ValueError as exc:
        msg = str(exc)
        click.echo(f"Could not parse reference: {msg}", err=True)
        click.echo(
            'Try a book, chapter, or verse — e.g. bs "John 3:16" or bs "Psalm 23"',
            err=True,
        )
        sys.exit(1)
    except Exception as exc:
        click.echo(f"Unexpected error: {exc}", err=True)
        sys.exit(1)

    render_terminal(note)

    if not no_notify:
        send_notification(note)

    if save:
        path = save_markdown(note)
        click.echo(f"Saved to: {path}")


if __name__ == "__main__":
    main()
