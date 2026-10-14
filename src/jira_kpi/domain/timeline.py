"""Ricostruzione dello storico degli stati di una issue a partire dal changelog."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from jira_kpi.domain.models import Issue, StatusCategory, StatusMapping


@dataclass(frozen=True)
class StatusInterval:
    status: str
    category: StatusCategory
    start: datetime
    end: datetime | None  # None = stato corrente

    def duration(self, now: datetime | None = None) -> timedelta:
        end = self.end or now
        if end is None:
            raise ValueError("intervallo aperto: specificare `now`")
        return end - self.start


def build_timeline(issue: Issue, mapping: StatusMapping) -> list[StatusInterval]:
    """Sequenza contigua di intervalli di stato, dalla creazione allo stato corrente."""
    transitions = issue.transitions
    status = (transitions[0].from_status if transitions else None) or (
        transitions[0].to_status if transitions else issue.status
    )
    start = issue.created
    intervals: list[StatusInterval] = []
    for t in transitions:
        intervals.append(StatusInterval(status, mapping.category(status), start, t.at))
        status, start = t.to_status, t.at
    intervals.append(StatusInterval(status, mapping.category(status), start, None))
    return intervals


def cycle_started_at(issue: Issue, mapping: StatusMapping) -> datetime | None:
    """Primo ingresso in uno stato attivo (in corso o in attesa)."""
    for interval in build_timeline(issue, mapping):
        if interval.category.is_started:
            return interval.start
    return None


def completed_at(issue: Issue, mapping: StatusMapping) -> datetime | None:
    """Ultimo ingresso in Done, solo se la issue è attualmente in Done."""
    timeline = build_timeline(issue, mapping)
    if timeline[-1].category is not StatusCategory.DONE:
        return None
    done_since = timeline[-1].start
    for interval in reversed(timeline[:-1]):
        if interval.category is not StatusCategory.DONE:
            break
        done_since = interval.start
    return done_since


def was_reopened(issue: Issue, mapping: StatusMapping) -> bool:
    timeline = build_timeline(issue, mapping)
    return any(
        prev.category is StatusCategory.DONE and nxt.category is not StatusCategory.DONE
        for prev, nxt in zip(timeline, timeline[1:], strict=False)
    )


def category_at(issue: Issue, mapping: StatusMapping, instant: datetime) -> StatusCategory | None:
    """Categoria di stato all'istante dato (None se la issue non esisteva ancora)."""
    if instant < issue.created:
        return None
    for interval in build_timeline(issue, mapping):
        if interval.end is None or instant < interval.end:
            return interval.category
    return None  # pragma: no cover - l'ultimo intervallo è sempre aperto
