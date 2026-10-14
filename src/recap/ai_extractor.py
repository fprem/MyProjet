"""Extract agreements, decisions and commitments from free-form notes with Claude.

Claude only reads the notes and returns structured data; the email itself is
still built by `recap_email.draft_recap`, so nothing is ever sent by the tool.
"""

from __future__ import annotations

from datetime import date
from typing import Any

from pydantic import BaseModel

from recap.notes_parser import Commitment, Meeting

MODEL = "claude-opus-5-5"

SYSTEM_PROMPT = """\
You help a project manager write the recap email after a call with an external \
client or supplier. Read the meeting notes or transcript and extract only what \
was actually said:

- title: a short name for the meeting, or null if unclear.
- agreements: things both sides agreed on, one short sentence each.
- decisions: choices that were made, one short sentence each.
- commitments: every promise to do something. owner is the person or company \
who will do it (null if nobody was named), task starts with a verb, and due is \
the date as YYYY-MM-DD (resolve relative dates such as "Friday" against the \
call date) or null if no date was given.

Do not invent items. Keep the wording close to the notes."""


class ExtractedCommitment(BaseModel):
    owner: str | None = None
    task: str
    due: str | None = None


class ExtractedMeeting(BaseModel):
    title: str | None = None
    agreements: list[str] = []
    decisions: list[str] = []
    commitments: list[ExtractedCommitment] = []


class AIDraftingError(Exception):
    """AI extraction failed; callers can fall back to the prefix parser."""


def _parse_due(value: str | None) -> date | None:
    try:
        return date.fromisoformat(value) if value else None
    except ValueError:
        return None


def _to_meeting(extracted: ExtractedMeeting) -> Meeting:
    return Meeting(
        title=extracted.title,
        agreements=list(extracted.agreements),
        decisions=list(extracted.decisions),
        commitments=[
            Commitment(owner=c.owner, task=c.task, due=_parse_due(c.due)) for c in extracted.commitments
        ],
    )


def _default_client() -> Any:
    import anthropic

    return anthropic.Anthropic()


def extract_with_ai(notes: str, call_date: date, client: Any = None) -> Meeting:
    try:
        client = client or _default_client()
        response = client.beta.messages.parse(
            model=MODEL,
            max_tokens=16000,
            system=SYSTEM_PROMPT,
            output_config={"effort": "medium"},
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
            messages=[{"role": "user", "content": f"Call date: {call_date.isoformat()}\n\nNotes:\n{notes}"}],
            output_format=ExtractedMeeting,
        )
    except Exception as exc:  # network, auth, missing key, ...
        raise AIDraftingError(f"AI drafting failed: {exc}") from exc
    if response.stop_reason == "refusal":
        raise AIDraftingError("AI drafting was declined for these notes.")
    if response.parsed_output is None:
        raise AIDraftingError(f"AI drafting returned no result (stop reason: {response.stop_reason}).")
    return _to_meeting(response.parsed_output)
