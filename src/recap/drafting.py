"""Pick how notes become a Meeting: AI extraction, or the prefix parser."""

from __future__ import annotations

from datetime import date
from typing import Callable

from recap.ai_extractor import AIDraftingError, extract_with_ai
from recap.notes_parser import Meeting, parse_notes

Extractor = Callable[[str, date], Meeting]


def build_meeting(
    notes: str, call_date: date, use_ai: bool, extractor: Extractor | None = None
) -> tuple[Meeting, str | None]:
    """Return the meeting and a notice to show the PM (None when all went well)."""
    if not use_ai:
        return parse_notes(notes), None
    extractor = extractor or (lambda text, d: extract_with_ai(text, call_date=d))
    try:
        return extractor(notes, call_date), None
    except AIDraftingError as exc:
        return parse_notes(notes), f"{exc} Used the Agreed:/Decision:/Action: lines instead."
