"""Success metrics from the one-pager, computed from a per-call log."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from difflib import SequenceMatcher
from statistics import median


@dataclass
class CallRecord:
    call_date: date
    pm: str
    sent: bool
    draft: str
    final: str | None = None
    call_end: datetime | None = None
    sent_at: datetime | None = None
    missed_commitments: int = 0


@dataclass
class Summary:
    calls: int
    send_rate: float
    avg_edit_share: float | None
    median_minutes_to_send: float | None
    missed_per_call: float

    @property
    def targets(self) -> dict[str, bool]:
        return {
            "send_rate>=70%": self.send_rate >= 0.70,
            "edit_share<20%": self.avg_edit_share is not None and self.avg_edit_share < 0.20,
            "minutes_to_send<5": self.median_minutes_to_send is not None and self.median_minutes_to_send < 5,
            "missed_per_call<1": self.calls > 0 and self.missed_per_call < 1,
        }


def edit_share(draft: str, final: str) -> float:
    """Share of the draft that changed before sending (0 = untouched, 1 = rewritten)."""
    return round(1 - SequenceMatcher(None, draft, final).ratio(), 4)


def summarize(records: list[CallRecord]) -> Summary:
    sent = [r for r in records if r.sent]
    edits = [edit_share(r.draft, r.final) for r in sent if r.final is not None]
    minutes = [(r.sent_at - r.call_end).total_seconds() / 60 for r in sent if r.sent_at and r.call_end]
    return Summary(
        calls=len(records),
        send_rate=len(sent) / len(records) if records else 0.0,
        avg_edit_share=sum(edits) / len(edits) if edits else None,
        median_minutes_to_send=median(minutes) if minutes else None,
        missed_per_call=sum(r.missed_commitments for r in records) / len(records) if records else 0.0,
    )
