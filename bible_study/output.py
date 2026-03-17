"""
Output renderers: terminal (rich), macOS notification, markdown file.
"""

from __future__ import annotations

import subprocess
from datetime import date
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.rule import Rule
from rich.text import Text

from bible_study.enrichment import StudyNote

console = Console()

_NOTES_DIR = Path(__file__).parent.parent / "notes"


def render_terminal(note: StudyNote) -> None:
    """Print a rich-formatted study note to the terminal."""
    console.print()
    console.print(
        Panel(
            Text(note.reference, style="bold white", justify="center"),
            style="bold blue",
            padding=(0, 2),
        )
    )

    if note.bible_text:
        console.print(
            Panel(
                note.bible_text,
                title="[bold green]ESV Text[/bold green]",
                border_style="green",
                padding=(1, 2),
            )
        )

    console.print(
        Panel(
            note.main_topic,
            title="[bold yellow]Main Topic[/bold yellow]",
            border_style="yellow",
            padding=(0, 2),
        )
    )

    console.print(
        Panel(
            note.context,
            title="[bold cyan]Context[/bold cyan]",
            border_style="cyan",
            padding=(1, 2),
        )
    )

    console.print(
        Panel(
            note.historical_cultural,
            title="[bold magenta]Historical & Cultural Background[/bold magenta]",
            border_style="magenta",
            padding=(1, 2),
        )
    )

    if note.cross_references:
        xref_lines = "\n".join(
            f"• [bold]{cr.reference}[/bold] — {cr.connection}"
            for cr in note.cross_references
        )
        console.print(
            Panel(
                xref_lines,
                title="[bold blue]Cross References[/bold blue]",
                border_style="blue",
                padding=(1, 2),
            )
        )

    if note.applications:
        app_lines = "\n".join(f"• {app}" for app in note.applications)
        console.print(
            Panel(
                app_lines,
                title="[bold red]Applications[/bold red]",
                border_style="red",
                padding=(1, 2),
            )
        )

    console.print()


def send_notification(note: StudyNote) -> None:
    """Send a macOS notification with the reference and main topic."""
    title = f"Bible Study: {note.reference}"
    message = note.main_topic
    try:
        subprocess.run(
            [
                "osascript",
                "-e",
                f'display notification "{message}" with title "{title}"',
            ],
            check=True,
            capture_output=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Non-fatal: notification may not work in all environments
        pass


def save_markdown(note: StudyNote) -> Path:
    """Save the study note as a markdown file in the notes/ directory."""
    _NOTES_DIR.mkdir(exist_ok=True)

    safe_ref = (
        note.reference.replace(" ", "_")
        .replace(":", "_")
        .replace("-", "-")
    )
    today = date.today().isoformat()
    filename = f"{safe_ref}_{today}.md"
    filepath = _NOTES_DIR / filename

    lines = [
        f"# {note.reference}",
        f"*{today}*",
        "",
    ]

    if note.bible_text:
        lines += [
            "## ESV Text",
            "",
            note.bible_text,
            "",
        ]

    lines += [
        "## Main Topic",
        "",
        note.main_topic,
        "",
        "## Context",
        "",
        note.context,
        "",
        "## Historical & Cultural Background",
        "",
        note.historical_cultural,
        "",
        "## Cross References",
        "",
    ]

    for cr in note.cross_references:
        lines.append(f"- **{cr.reference}** — {cr.connection}")
    lines.append("")

    lines += [
        "## Applications",
        "",
    ]
    for app in note.applications:
        lines.append(f"- {app}")
    lines.append("")

    filepath.write_text("\n".join(lines), encoding="utf-8")
    return filepath
