"""KPI Scrum: velocity, commitment (say/do), scope change, carry-over."""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import datetime

from jira_kpi.domain.models import Issue, Sprint, StatusCategory, StatusMapping
from jira_kpi.domain.timeline import category_at


def sprints_at(issue: Issue, instant: datetime) -> frozenset[int]:
    """Valore del campo Sprint all'istante dato, ricostruito dal changelog."""
    changes = issue.sprint_changes
    if not changes:
        return issue.sprint_ids
    value = changes[0].from_ids
    for change in changes:
        if change.at > instant:
            break
        value = change.to_ids
    return value


@dataclass(frozen=True)
class SprintReport:
    sprint: Sprint
    committed_points: float
    committed_count: int
    added_points: float
    removed_points: float
    completed_points: float
    completed_count: int
    carried_over_points: float
    carried_over_count: int
    say_do_ratio: float | None


def _added_during(issue: Issue, sprint_id: int, start: datetime, end: datetime) -> bool:
    return any(
        start < c.at <= end and sprint_id in c.to_ids and sprint_id not in c.from_ids
        for c in issue.sprint_changes
    )


def sprint_report(sprint: Sprint, issues: Iterable[Issue], mapping: StatusMapping) -> SprintReport:
    start, end = sprint.start, sprint.effective_end
    if start is None or end is None:
        raise ValueError(f"lo sprint {sprint.name!r} non ha date di inizio/fine")

    committed: list[Issue] = []
    added: list[Issue] = []
    removed: list[Issue] = []
    completed: list[Issue] = []
    carried: list[Issue] = []
    for issue in issues:
        at_start = sprint.id in sprints_at(issue, start)
        if at_start:
            committed.append(issue)
        elif _added_during(issue, sprint.id, start, end):
            added.append(issue)
        else:
            continue
        if sprint.id not in sprints_at(issue, end):
            removed.append(issue)
        elif category_at(issue, mapping, end) is StatusCategory.DONE:
            completed.append(issue)
        else:
            carried.append(issue)

    def points(items: Iterable[Issue]) -> float:
        return sum(i.points for i in items)

    committed_points = points(committed)
    committed_keys = {i.key for i in committed}
    delivered_commitment = points(i for i in completed if i.key in committed_keys)
    return SprintReport(
        sprint=sprint,
        committed_points=committed_points,
        committed_count=len(committed),
        added_points=points(added),
        removed_points=points(removed),
        completed_points=points(completed),
        completed_count=len(completed),
        carried_over_points=points(carried),
        carried_over_count=len(carried),
        say_do_ratio=delivered_commitment / committed_points if committed_points else None,
    )


def sprint_reports(
    sprints: Iterable[Sprint], issues: Sequence[Issue], mapping: StatusMapping
) -> list[SprintReport]:
    """Report per tutti gli sprint avviati, in ordine di inizio."""
    started = [s for s in sprints if s.start is not None and s.effective_end is not None]
    started.sort(key=lambda s: s.start)  # type: ignore[arg-type, return-value]
    return [sprint_report(s, issues, mapping) for s in started]


def rolling_average(values: Sequence[float], window: int) -> list[float]:
    result = []
    for i in range(len(values)):
        chunk = values[max(0, i - window + 1) : i + 1]
        result.append(sum(chunk) / len(chunk))
    return result
