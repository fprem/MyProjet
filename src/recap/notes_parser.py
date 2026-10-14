"""Parse meeting notes into agreements, decisions and commitments.

Notes are plain text. Lines are classified by a prefix (case-insensitive,
optional leading bullet):

    Agreed: <text>           -> agreement
    Decision: <text>         -> decision
    Action: / TODO: <text>   -> commitment, "<owner> to|will <task> [by YYYY-MM-DD]"

The first line without a known prefix is the meeting title; other lines are
ignored.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date

_PREFIX = re.compile(r"^\s*(?:[-*•]\s*)?(agreed|agreement|decision|decided|action|todo)\s*:\s*(.+)$", re.I)
_COMMITMENT = re.compile(
    r"^(?:(?P<owner>.+?)\s+(?:to|will)\s+)?(?P<task>.+?)(?:\s+by\s+(?P<due>\d{4}-\d{2}-\d{2}))?$",
    re.I,
)


@dataclass(frozen=True)
class Commitment:
    owner: str | None
    task: str
    due: date | None = None


@dataclass
class Meeting:
    title: str | None = None
    agreements: list[str] = field(default_factory=list)
    decisions: list[str] = field(default_factory=list)
    commitments: list[Commitment] = field(default_factory=list)

    def is_empty(self) -> bool:
        return not (self.agreements or self.decisions or self.commitments)


def _sentence(text: str) -> str:
    text = text.strip()
    return text[:1].upper() + text[1:]


def parse_commitment(text: str) -> Commitment:
    match = _COMMITMENT.match(text.strip())
    assert match  # the pattern matches any non-empty text
    due = date.fromisoformat(match["due"]) if match["due"] else None
    owner = match["owner"].strip() if match["owner"] else None
    return Commitment(owner=owner, task=match["task"].strip(), due=due)


def parse_notes(text: str) -> Meeting:
    meeting = Meeting()
    for line in text.splitlines():
        if not line.strip():
            continue
        match = _PREFIX.match(line)
        if not match:
            if meeting.title is None:
                meeting.title = line.strip()
            continue
        kind, body = match[1].lower(), match[2]
        if kind in ("agreed", "agreement"):
            meeting.agreements.append(_sentence(body))
        elif kind in ("decision", "decided"):
            meeting.decisions.append(_sentence(body))
        else:
            meeting.commitments.append(parse_commitment(body))
    return meeting
