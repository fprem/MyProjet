"""Builder per costruire issue di test in modo leggibile."""

from __future__ import annotations

from datetime import UTC, datetime

from jira_kpi.domain.models import (
    Issue,
    SprintChange,
    StatusCategory,
    StatusMapping,
    StatusTransition,
)

MAPPING = StatusMapping(
    {
        "to do": StatusCategory.TODO,
        "in progress": StatusCategory.IN_PROGRESS,
        "code review": StatusCategory.IN_PROGRESS,
        "waiting for qa": StatusCategory.WAITING,
        "done": StatusCategory.DONE,
    }
)


def dt(day: int, hour: int = 0, month: int = 1, year: int = 2026) -> datetime:
    return datetime(year, month, day, hour, tzinfo=UTC)


def make_issue(
    key: str = "PRJ-1",
    *,
    created: datetime | None = None,
    transitions: list[tuple[datetime, str]] | None = None,
    initial_status: str = "To Do",
    issue_type: str = "Story",
    story_points: float | None = None,
    priority: str | None = "Medium",
    sprint_ids: frozenset[int] = frozenset(),
    sprint_changes: list[tuple[datetime, set[int], set[int]]] | None = None,
) -> Issue:
    """Crea una issue; `transitions` = lista di (istante, nuovo stato) in ordine."""
    created = created or dt(1)
    trans: list[StatusTransition] = []
    current = initial_status
    for at, to_status in transitions or []:
        trans.append(StatusTransition(at=at, from_status=current, to_status=to_status))
        current = to_status
    changes = tuple(
        SprintChange(at=at, from_ids=frozenset(before), to_ids=frozenset(after))
        for at, before, after in sprint_changes or []
    )
    return Issue(
        key=key,
        issue_type=issue_type,
        created=created,
        status=current,
        story_points=story_points,
        priority=priority,
        transitions=tuple(trans),
        sprint_ids=sprint_ids,
        sprint_changes=changes,
    )
