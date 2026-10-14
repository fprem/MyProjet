"""Modelli di dominio immutabili, indipendenti da Jira."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field, replace
from datetime import datetime, timedelta
from enum import StrEnum


class StatusCategory(StrEnum):
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    WAITING = "waiting"
    DONE = "done"

    @property
    def is_started(self) -> bool:
        return self in (StatusCategory.IN_PROGRESS, StatusCategory.WAITING)


def _require_aware(value: datetime, name: str) -> None:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError(f"{name} deve avere un timezone")


def _normalize(status: str) -> str:
    return status.strip().casefold()


class StatusMapping:
    """Associa i nomi di stato del workflow Jira a una categoria (case-insensitive)."""

    def __init__(
        self,
        mapping: Mapping[str, StatusCategory],
        default: StatusCategory = StatusCategory.TODO,
    ) -> None:
        self._mapping = {_normalize(k): v for k, v in mapping.items()}
        self.default = default

    def category(self, status: str) -> StatusCategory:
        return self._mapping.get(_normalize(status), self.default)


@dataclass(frozen=True)
class StatusTransition:
    at: datetime
    from_status: str | None
    to_status: str

    def __post_init__(self) -> None:
        _require_aware(self.at, "at")


@dataclass(frozen=True)
class SprintChange:
    """Cambio del campo Sprint: insiemi di id sprint prima e dopo la modifica."""

    at: datetime
    from_ids: frozenset[int]
    to_ids: frozenset[int]

    def __post_init__(self) -> None:
        _require_aware(self.at, "at")


@dataclass(frozen=True)
class Sprint:
    id: int
    name: str
    state: str
    start: datetime | None = None
    end: datetime | None = None
    complete_date: datetime | None = None

    @property
    def effective_end(self) -> datetime | None:
        return self.complete_date or self.end


@dataclass(frozen=True)
class Issue:
    key: str
    issue_type: str
    created: datetime
    status: str
    story_points: float | None = None
    priority: str | None = None
    transitions: tuple[StatusTransition, ...] = ()
    sprint_ids: frozenset[int] = field(default_factory=frozenset)
    sprint_changes: tuple[SprintChange, ...] = ()

    def __post_init__(self) -> None:
        _require_aware(self.created, "created")
        object.__setattr__(self, "transitions", tuple(sorted(self.transitions, key=lambda t: t.at)))
        object.__setattr__(
            self, "sprint_changes", tuple(sorted(self.sprint_changes, key=lambda c: c.at))
        )

    @property
    def points(self) -> float:
        return float(self.story_points or 0.0)

    def with_transitions(self, transitions: tuple[StatusTransition, ...]) -> Issue:
        return replace(self, transitions=transitions)


@dataclass(frozen=True)
class Period:
    """Intervallo semiaperto [start, end)."""

    start: datetime
    end: datetime

    def __post_init__(self) -> None:
        _require_aware(self.start, "start")
        _require_aware(self.end, "end")
        if self.end <= self.start:
            raise ValueError("end deve essere successivo a start")

    @property
    def length(self) -> timedelta:
        return self.end - self.start

    def contains(self, instant: datetime) -> bool:
        return self.start <= instant < self.end

    def previous(self) -> Period:
        return Period(self.start - self.length, self.start)
