"""Conversione del JSON restituito dall'API Jira Cloud in modelli di dominio."""

from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime
from typing import Any

from jira_kpi.domain.models import Issue, Sprint, SprintChange, StatusTransition

RawIssue = dict[str, Any]


def parse_jira_datetime(value: str) -> datetime:
    """Accetta i formati Jira (`...000+0100`, `...000Z`) e ISO 8601."""
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _optional_datetime(value: str | None) -> datetime | None:
    return parse_jira_datetime(value) if value else None


def _parse_sprint_ids(value: str | None) -> frozenset[int]:
    if not value:
        return frozenset()
    return frozenset(int(part) for part in value.split(",") if part.strip())


def _name(value: dict[str, Any] | None) -> str | None:
    return value.get("name") if value else None


class IssueMapper:
    def __init__(
        self, story_points_field: str, sprint_field: str, board_id: int | None = None
    ) -> None:
        self.story_points_field = story_points_field
        self.sprint_field = sprint_field
        self.board_id = board_id

    def _is_sprint_item(self, item: dict[str, Any]) -> bool:
        return bool(item.get("fieldId") == self.sprint_field or item.get("field") == "Sprint")

    def to_issue(self, raw: RawIssue) -> Issue:
        fields = raw["fields"]
        transitions: list[StatusTransition] = []
        sprint_changes: list[SprintChange] = []
        for history in (raw.get("changelog") or {}).get("histories", []):
            at = parse_jira_datetime(history["created"])
            for item in history.get("items", []):
                if item.get("fieldId") == "status" or item.get("field") == "status":
                    transitions.append(
                        StatusTransition(at, item.get("fromString"), item["toString"])
                    )
                elif self._is_sprint_item(item):
                    sprint_changes.append(
                        SprintChange(
                            at,
                            _parse_sprint_ids(item.get("from")),
                            _parse_sprint_ids(item.get("to")),
                        )
                    )
        points = fields.get(self.story_points_field)
        return Issue(
            key=raw["key"],
            issue_type=fields["issuetype"]["name"],
            created=parse_jira_datetime(fields["created"]),
            status=fields["status"]["name"],
            story_points=float(points) if points is not None else None,
            priority=_name(fields.get("priority")),
            transitions=tuple(transitions),
            sprint_ids=frozenset(s["id"] for s in fields.get(self.sprint_field) or []),
            sprint_changes=tuple(sprint_changes),
        )

    def extract_sprints(self, raws: Iterable[RawIssue]) -> list[Sprint]:
        """Sprint distinti referenziati dalle issue, ordinati per id."""
        sprints: dict[int, Sprint] = {}
        for raw in raws:
            for s in raw["fields"].get(self.sprint_field) or []:
                if self.board_id is not None and s.get("boardId") != self.board_id:
                    continue
                sprints[s["id"]] = Sprint(
                    id=s["id"],
                    name=s["name"],
                    state=s.get("state", ""),
                    start=_optional_datetime(s.get("startDate")),
                    end=_optional_datetime(s.get("endDate")),
                    complete_date=_optional_datetime(s.get("completeDate")),
                )
        return [sprints[k] for k in sorted(sprints)]
