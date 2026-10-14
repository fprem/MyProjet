"""Draft the recap email the PM reviews and sends from their own inbox."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from recap.notes_parser import Commitment, Meeting


@dataclass(frozen=True)
class RecapEmail:
    subject: str
    body: str

    def as_text(self) -> str:
        return f"Subject: {self.subject}\n\n{self.body}"


def _short_date(d: date) -> str:
    return f"{d:%a} {d.day} {d:%b}"


def _next_step(c: Commitment) -> str:
    line = f"- {c.owner or 'To be assigned'}: {c.task}"
    if c.due:
        line += f" (by {_short_date(c.due)})"
    return line


def draft_recap(meeting: Meeting, client: str, pm_name: str, call_date: date) -> RecapEmail:
    subject = f"Recap: {meeting.title or 'our call'} ({client}, {call_date.day} {call_date:%b %Y})"

    parts = ["Hi all,", "Thanks for your time today. Here is a short recap of our call."]
    sections = [
        ("What we agreed", [f"- {a}" for a in meeting.agreements]),
        ("Decisions", [f"- {d}" for d in meeting.decisions]),
        ("Next steps", [_next_step(c) for c in meeting.commitments]),
    ]
    for heading, lines in sections:
        if lines:
            parts.append("\n".join([heading, *lines]))
    parts.append("Please reply if I missed or misunderstood anything.")
    parts.append(f"Best regards,\n{pm_name}")
    return RecapEmail(subject=subject, body="\n\n".join(parts) + "\n")
