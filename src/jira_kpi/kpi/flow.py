"""KPI di flusso: throughput, cycle/lead time, WIP, flow efficiency, aging."""

from __future__ import annotations

import math
from collections import Counter
from collections.abc import Callable, Iterable, Iterator, Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, tzinfo

from jira_kpi.domain.models import Issue, Period, StatusCategory, StatusMapping
from jira_kpi.domain.timeline import (
    build_timeline,
    category_at,
    completed_at,
    cycle_started_at,
)

SECONDS_PER_DAY = 86_400.0
_EPSILON = timedelta(microseconds=1)


def _days(delta: timedelta) -> float:
    return delta.total_seconds() / SECONDS_PER_DAY


def percentile(values: Sequence[float], p: float) -> float:
    """Percentile con interpolazione lineare (come numpy `linear`)."""
    if not values:
        raise ValueError("percentile di una sequenza vuota")
    if not 0 <= p <= 100:
        raise ValueError("p deve essere compreso tra 0 e 100")
    ordered = sorted(values)
    rank = (len(ordered) - 1) * p / 100
    low, high = math.floor(rank), math.ceil(rank)
    return ordered[low] + (ordered[high] - ordered[low]) * (rank - low)


@dataclass(frozen=True)
class DurationStats:
    count: int
    mean: float
    p50: float
    p85: float
    p95: float


def duration_stats(days: Sequence[float]) -> DurationStats | None:
    if not days:
        return None
    return DurationStats(
        count=len(days),
        mean=sum(days) / len(days),
        p50=percentile(days, 50),
        p85=percentile(days, 85),
        p95=percentile(days, 95),
    )


@dataclass(frozen=True)
class IssueDuration:
    key: str
    days: float
    completed_at: datetime


def _durations(
    issues: Iterable[Issue],
    mapping: StatusMapping,
    period: Period,
    start_of: Callable[[Issue], datetime | None],
) -> list[IssueDuration]:
    result = []
    for issue in issues:
        done = completed_at(issue, mapping)
        start = start_of(issue)
        if done is None or start is None or not period.contains(done):
            continue
        result.append(IssueDuration(issue.key, _days(done - start), done))
    return sorted(result, key=lambda d: d.completed_at)


def cycle_times(
    issues: Iterable[Issue], mapping: StatusMapping, period: Period
) -> list[IssueDuration]:
    """Dal primo stato attivo al completamento; esclude issue mai avviate."""
    return _durations(issues, mapping, period, lambda i: cycle_started_at(i, mapping))


def lead_times(
    issues: Iterable[Issue], mapping: StatusMapping, period: Period
) -> list[IssueDuration]:
    """Dalla creazione al completamento."""
    return _durations(issues, mapping, period, lambda i: i.created)


def _local_days(period: Period, tz: tzinfo) -> Iterator[date]:
    day = period.start.astimezone(tz).date()
    last = (period.end - _EPSILON).astimezone(tz).date()
    while day <= last:
        yield day
        day += timedelta(days=1)


def throughput(
    issues: Iterable[Issue], mapping: StatusMapping, period: Period, tz: tzinfo
) -> list[tuple[date, int]]:
    """Issue completate per settimana ISO (chiave = lunedì), settimane vuote incluse."""

    def week_of(d: date) -> date:
        return d - timedelta(days=d.weekday())

    counts: Counter[date] = Counter()
    for issue in issues:
        done = completed_at(issue, mapping)
        if done is not None and period.contains(done):
            counts[week_of(done.astimezone(tz).date())] += 1
    weeks = sorted({week_of(d) for d in _local_days(period, tz)})
    return [(w, counts[w]) for w in weeks]


def cumulative_flow(
    issues: Sequence[Issue], mapping: StatusMapping, period: Period, tz: tzinfo
) -> list[tuple[date, dict[StatusCategory, int]]]:
    """Numero di issue per categoria a fine giornata (ora locale)."""
    result = []
    for day in _local_days(period, tz):
        end_of_day = datetime.combine(day + timedelta(days=1), time(), tz) - _EPSILON
        counts: Counter[StatusCategory] = Counter()
        for issue in issues:
            category = category_at(issue, mapping, end_of_day)
            if category is not None:
                counts[category] += 1
        result.append((day, dict(counts)))
    return result


def daily_wip(
    issues: Sequence[Issue], mapping: StatusMapping, period: Period, tz: tzinfo
) -> list[tuple[date, int]]:
    return [
        (day, sum(n for cat, n in counts.items() if cat.is_started))
        for day, counts in cumulative_flow(issues, mapping, period, tz)
    ]


def flow_efficiency(
    issues: Iterable[Issue], mapping: StatusMapping, period: Period
) -> float | None:
    """Tempo in stati attivi / tempo di ciclo totale, aggregato sulle issue completate."""
    active = total = 0.0
    for issue in issues:
        start, done = cycle_started_at(issue, mapping), completed_at(issue, mapping)
        if start is None or done is None or not period.contains(done):
            continue
        for interval in build_timeline(issue, mapping):
            if interval.end is None:
                continue
            overlap_start, overlap_end = max(interval.start, start), min(interval.end, done)
            if overlap_end <= overlap_start:
                continue
            seconds = (overlap_end - overlap_start).total_seconds()
            total += seconds
            if interval.category is StatusCategory.IN_PROGRESS:
                active += seconds
    return active / total if total else None


@dataclass(frozen=True)
class AgingItem:
    key: str
    status: str
    age_days: float


def aging_wip(issues: Iterable[Issue], mapping: StatusMapping, now: datetime) -> list[AgingItem]:
    """Età (dal primo stato attivo) delle issue attualmente in lavorazione."""
    items = []
    for issue in issues:
        start = cycle_started_at(issue, mapping)
        if start is None or not mapping.category(issue.status).is_started:
            continue
        items.append(AgingItem(issue.key, issue.status, _days(now - start)))
    return sorted(items, key=lambda a: a.age_days, reverse=True)
