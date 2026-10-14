"""Caricamento dello snapshot locale e periodi predefiniti per la dashboard."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time, timedelta, tzinfo

from jira_kpi.config import Settings
from jira_kpi.domain.models import Issue, Period, Sprint
from jira_kpi.jira.mapper import IssueMapper
from jira_kpi.storage.repository import IssueRepository

# etichetta -> durata in giorni
PRESETS: dict[str, int] = {
    "Ultime 2 settimane": 14,
    "Ultimi 30 giorni": 30,
    "Ultimi 90 giorni": 90,
    "Ultimi 180 giorni": 180,
}


@dataclass(frozen=True)
class Dataset:
    issues: list[Issue]
    sprints: list[Sprint]
    last_sync: datetime | None


def period_for_preset(preset: str, now: datetime, tz: tzinfo) -> Period:
    """Periodo che termina alla fine della giornata odierna (ora locale)."""
    days = PRESETS[preset]
    end = datetime.combine(now.astimezone(tz).date() + timedelta(days=1), time(), tz)
    return Period(end - timedelta(days=days), end)


def load_dataset(settings: Settings) -> Dataset:
    mapper = IssueMapper(settings.story_points_field, settings.sprint_field, settings.board_id)
    with IssueRepository(settings.db_path) as repo:
        raws = repo.load_all()
        last_sync = repo.last_sync()
    return Dataset(
        issues=[mapper.to_issue(r) for r in raws],
        sprints=mapper.extract_sprints(raws),
        last_sync=last_sync,
    )
