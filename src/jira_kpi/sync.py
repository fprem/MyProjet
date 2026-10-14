"""Orchestrazione: scarica da Jira e aggiorna lo snapshot locale."""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Protocol

from jira_kpi.config import Settings
from jira_kpi.storage.repository import IssueRepository

# Margine sull'ultima sync: copre differenze di fuso tra JQL e orologio locale.
SAFETY_MARGIN = timedelta(days=1)
BASE_FIELDS = ["summary", "issuetype", "status", "priority", "created", "updated"]


class IssueSource(Protocol):
    def search_issues(self, jql: str, fields: list[str]) -> Iterator[dict[str, Any]]: ...

    def get_changelog(self, key: str) -> list[dict[str, Any]]: ...


@dataclass(frozen=True)
class SyncResult:
    fetched: int
    total: int
    full: bool


def _complete_changelog(client: IssueSource, raw: dict[str, Any]) -> dict[str, Any]:
    changelog = raw.get("changelog") or {}
    histories = changelog.get("histories", [])
    if changelog.get("total", len(histories)) > len(histories):
        full = client.get_changelog(raw["key"])
        raw = {**raw, "changelog": {**changelog, "histories": full, "total": len(full)}}
    return raw


def sync(
    client: IssueSource,
    repo: IssueRepository,
    settings: Settings,
    now: datetime,
    *,
    full: bool = False,
) -> SyncResult:
    reset = repo.ensure_scope(settings.jql)
    last = repo.last_sync()
    if full:
        repo.clear()
    is_full = full or reset or last is None
    jql = settings.jql
    if not is_full and last is not None:
        since = (last - SAFETY_MARGIN).astimezone(settings.tz).strftime("%Y-%m-%d %H:%M")
        jql = f'({settings.jql}) AND updated >= "{since}"'

    fields = [*BASE_FIELDS, settings.story_points_field, settings.sprint_field]
    raws = [_complete_changelog(client, raw) for raw in client.search_issues(jql, fields)]
    repo.upsert(raws)
    repo.set_last_sync(now)
    return SyncResult(fetched=len(raws), total=repo.count(), full=is_full)
