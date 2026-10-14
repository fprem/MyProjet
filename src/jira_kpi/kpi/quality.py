"""KPI di qualità: bug ratio, tempi di risoluzione dei bug, tasso di riapertura."""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable, Sequence

from jira_kpi.domain.models import Issue, Period, StatusMapping
from jira_kpi.domain.timeline import completed_at, was_reopened
from jira_kpi.kpi.flow import DurationStats, duration_stats, lead_times


def _is_bug(issue: Issue, bug_types: Iterable[str]) -> bool:
    return issue.issue_type.casefold() in {t.casefold() for t in bug_types}


def _completed_in(issues: Iterable[Issue], mapping: StatusMapping, period: Period) -> list[Issue]:
    result = []
    for issue in issues:
        done = completed_at(issue, mapping)
        if done is not None and period.contains(done):
            result.append(issue)
    return result


def bug_ratio(
    issues: Sequence[Issue], mapping: StatusMapping, period: Period, bug_types: Iterable[str]
) -> float | None:
    """Bug creati nel periodo / issue completate nel periodo."""
    completed = _completed_in(issues, mapping, period)
    if not completed:
        return None
    bugs = sum(1 for i in issues if _is_bug(i, bug_types) and period.contains(i.created))
    return bugs / len(completed)


def bug_resolution_times(
    issues: Iterable[Issue], mapping: StatusMapping, period: Period, bug_types: Iterable[str]
) -> dict[str, DurationStats]:
    """Lead time dei bug completati nel periodo, raggruppato per priorità."""
    bugs = [i for i in issues if _is_bug(i, bug_types)]
    priority = {b.key: b.priority or "None" for b in bugs}
    grouped: dict[str, list[float]] = defaultdict(list)
    for duration in lead_times(bugs, mapping, period):
        grouped[priority[duration.key]].append(duration.days)
    return {p: stats for p, days in grouped.items() if (stats := duration_stats(days))}


def reopen_rate(issues: Iterable[Issue], mapping: StatusMapping, period: Period) -> float | None:
    """Quota delle issue completate nel periodo che sono state riaperte almeno una volta."""
    completed = _completed_in(issues, mapping, period)
    if not completed:
        return None
    return sum(1 for i in completed if was_reopened(i, mapping)) / len(completed)
