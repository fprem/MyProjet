"""Trasforma i KPI in dati pronti per la UI (logica pura, testabile senza Streamlit)."""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date, datetime, tzinfo
from statistics import mean
from typing import Literal

from jira_kpi.domain.models import Issue, Period, Sprint, StatusCategory, StatusMapping
from jira_kpi.domain.timeline import category_at
from jira_kpi.kpi.flow import (
    AgingItem,
    DurationStats,
    IssueDuration,
    aging_wip,
    cumulative_flow,
    cycle_times,
    duration_stats,
    flow_efficiency,
    lead_times,
    throughput,
)
from jira_kpi.kpi.quality import bug_ratio, bug_resolution_times, reopen_rate
from jira_kpi.kpi.scrum import SprintReport, rolling_average, sprint_reports

Trend = Literal["better", "worse", "flat"]
MAX_SPRINTS = 12


@dataclass(frozen=True)
class KpiTile:
    key: str
    label: str
    value: float | None
    previous: float | None
    unit: str
    higher_is_better: bool
    help: str = ""

    @property
    def delta(self) -> float | None:
        if self.value is None or self.previous is None:
            return None
        return self.value - self.previous

    @property
    def trend(self) -> Trend | None:
        delta = self.delta
        if delta is None:
            return None
        if delta == 0:
            return "flat"
        return "better" if (delta > 0) == self.higher_is_better else "worse"


@dataclass(frozen=True)
class DashboardData:
    period: Period
    tiles: list[KpiTile]
    throughput: list[tuple[date, int]]
    cfd: list[tuple[date, dict[StatusCategory, int]]]
    cycle_time_points: list[IssueDuration]
    cycle_time_stats: DurationStats | None
    aging: list[AgingItem]
    sprints: list[SprintReport]
    velocity_trend: list[float]
    bug_resolution: dict[str, DurationStats]


def _wip_at(issues: Iterable[Issue], mapping: StatusMapping, instant: datetime) -> int:
    count = 0
    for issue in issues:
        category = category_at(issue, mapping, instant)
        if category is not None and category.is_started:
            count += 1
    return count


def _mean_or_none(values: Iterable[float | None]) -> float | None:
    present = [v for v in values if v is not None]
    return mean(present) if present else None


def _p(stats: DurationStats | None, attr: str) -> float | None:
    return getattr(stats, attr) if stats else None


def _period_metrics(
    issues: Sequence[Issue],
    reports: Sequence[SprintReport],
    mapping: StatusMapping,
    period: Period,
    wip_instant: datetime,
    bug_types: Sequence[str],
) -> dict[str, float | None]:
    cycle = duration_stats([d.days for d in cycle_times(issues, mapping, period)])
    completed = lead_times(issues, mapping, period)  # ogni issue completata ha un lead time
    lead = duration_stats([d.days for d in completed])
    in_period = [
        r for r in reports if r.sprint.effective_end and period.contains(r.sprint.effective_end)
    ]
    return {
        "throughput": float(len(completed)),
        "cycle_time_p85": _p(cycle, "p85"),
        "lead_time_p50": _p(lead, "p50"),
        "wip": float(_wip_at(issues, mapping, wip_instant)),
        "flow_efficiency": flow_efficiency(issues, mapping, period),
        "velocity": _mean_or_none(r.completed_points for r in in_period),
        "say_do": _mean_or_none(r.say_do_ratio for r in in_period),
        "bug_ratio": bug_ratio(issues, mapping, period, bug_types),
        "reopen_rate": reopen_rate(issues, mapping, period),
    }


# (chiave, etichetta, unità, più alto = meglio, descrizione)
TILE_SPECS: list[tuple[str, str, str, bool, str]] = [
    ("throughput", "Throughput", "issue", True, "Issue completate nel periodo"),
    (
        "cycle_time_p85",
        "Cycle time p85",
        "giorni",
        False,
        "85% delle issue completate entro questo tempo dall'avvio",
    ),
    ("lead_time_p50", "Lead time p50", "giorni", False, "Mediana creazione → Done"),
    ("wip", "WIP", "issue", False, "Issue in lavorazione a fine periodo"),
    ("flow_efficiency", "Flow efficiency", "%", True, "Tempo attivo / tempo di ciclo"),
    ("velocity", "Velocity", "SP", True, "Media SP completati negli sprint chiusi nel periodo"),
    ("say_do", "Say/Do", "%", True, "SP committati completati / SP committati"),
    ("bug_ratio", "Bug ratio", "%", False, "Bug creati / issue completate"),
    ("reopen_rate", "Reopen rate", "%", False, "Issue completate che erano state riaperte"),
]


def build_dashboard(
    issues: Sequence[Issue],
    sprints: Sequence[Sprint],
    mapping: StatusMapping,
    period: Period,
    *,
    now: datetime,
    tz: tzinfo,
    bug_types: Sequence[str],
) -> DashboardData:
    reports = sprint_reports(sprints, issues, mapping)
    current = _period_metrics(issues, reports, mapping, period, min(now, period.end), bug_types)
    previous_period = period.previous()
    previous = _period_metrics(
        issues, reports, mapping, previous_period, previous_period.end, bug_types
    )
    tiles = [
        KpiTile(key, label, current[key], previous[key], unit, better, help_)
        for key, label, unit, better, help_ in TILE_SPECS
    ]
    visible = [r for r in reports if r.sprint.start and r.sprint.start < period.end][-MAX_SPRINTS:]
    cycle = cycle_times(issues, mapping, period)
    return DashboardData(
        period=period,
        tiles=tiles,
        throughput=throughput(issues, mapping, period, tz),
        cfd=cumulative_flow(issues, mapping, period, tz),
        cycle_time_points=cycle,
        cycle_time_stats=duration_stats([d.days for d in cycle]),
        aging=aging_wip(issues, mapping, now),
        sprints=visible,
        velocity_trend=rolling_average([r.completed_points for r in visible], 3),
        bug_resolution=bug_resolution_times(issues, mapping, period, bug_types),
    )
