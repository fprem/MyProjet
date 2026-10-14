from zoneinfo import ZoneInfo

import pytest

from jira_kpi.app.viewmodel import DashboardData, KpiTile, build_dashboard
from jira_kpi.domain.models import Period, Sprint
from tests.builders import MAPPING, dt, make_issue

UTC = ZoneInfo("UTC")


class TestKpiTile:
    @pytest.mark.parametrize(
        ("value", "previous", "higher_is_better", "trend"),
        [
            (10, 5, True, "better"),
            (10, 5, False, "worse"),
            (3, 6, False, "better"),
            (5, 5, True, "flat"),
            (None, 5, True, None),
            (5, None, True, None),
        ],
    )
    def test_trend(
        self, value: float | None, previous: float | None, higher_is_better: bool, trend: str | None
    ) -> None:
        tile = KpiTile("k", "K", value, previous, "", higher_is_better)
        assert tile.trend == trend

    def test_delta(self) -> None:
        assert KpiTile("k", "K", 7, 4, "", True).delta == 3
        assert KpiTile("k", "K", None, 4, "", True).delta is None


def scenario() -> tuple[list, list[Sprint], Period]:  # type: ignore[type-arg]
    sprint = Sprint(10, "S10", "closed", start=dt(5), end=dt(19), complete_date=dt(19))
    issues = [
        # completate nel periodo corrente (12-26 gen)
        make_issue(
            "A-1",
            story_points=5,
            transitions=[(dt(13), "In Progress"), (dt(15), "Done")],
            sprint_ids=frozenset({10}),
            sprint_changes=[(dt(4), set(), {10})],
        ),
        make_issue(
            "A-2",
            story_points=3,
            transitions=[(dt(14), "In Progress"), (dt(18), "Done")],
            sprint_ids=frozenset({10}),
            sprint_changes=[(dt(4), set(), {10})],
        ),
        # completata nel periodo precedente (29 dic - 12 gen)
        make_issue("A-3", created=dt(1), transitions=[(dt(2), "In Progress"), (dt(8), "Done")]),
        # in lavorazione
        make_issue("A-4", transitions=[(dt(20), "In Progress")]),
        make_issue(
            "B-1", issue_type="Bug", created=dt(16), priority="High", transitions=[(dt(17), "Done")]
        ),
    ]
    return issues, [sprint], Period(dt(12), dt(26))


class TestBuildDashboard:
    def test_tiles_compare_with_previous_period(self) -> None:
        issues, sprints, period = scenario()
        data = build_dashboard(
            issues, sprints, MAPPING, period, now=dt(25), tz=UTC, bug_types=["Bug"]
        )
        tiles = {t.key: t for t in data.tiles}
        assert tiles["throughput"].value == 3
        assert tiles["throughput"].previous == 1
        assert tiles["cycle_time_p85"].value == pytest.approx(3.7)
        assert tiles["cycle_time_p85"].higher_is_better is False
        assert tiles["wip"].value == 1
        assert tiles["bug_ratio"].value == pytest.approx(1 / 3)
        assert tiles["velocity"].value == 8
        assert tiles["say_do"].value == pytest.approx(1.0)
        assert tiles["reopen_rate"].value == 0

    def test_series(self) -> None:
        issues, sprints, period = scenario()
        data = build_dashboard(
            issues, sprints, MAPPING, period, now=dt(25), tz=UTC, bug_types=["Bug"]
        )
        assert sum(n for _, n in data.throughput) == 3
        assert [p.key for p in data.cycle_time_points] == ["A-1", "A-2"]
        assert data.cycle_time_stats is not None
        assert [a.key for a in data.aging] == ["A-4"]
        assert len(data.cfd) == 14
        assert [r.sprint.id for r in data.sprints] == [10]
        assert data.velocity_trend == [8.0]
        assert set(data.bug_resolution) == {"High"}

    def test_empty_dataset(self) -> None:
        data = build_dashboard(
            [], [], MAPPING, Period(dt(12), dt(26)), now=dt(25), tz=UTC, bug_types=["Bug"]
        )
        tiles = {t.key: t for t in data.tiles}
        assert tiles["throughput"].value == 0
        assert tiles["cycle_time_p85"].value is None
        assert tiles["velocity"].value is None
        assert data.sprints == []


class TestActiveSprint:
    def _build(self, *extra: Sprint) -> "DashboardData":
        issues, sprints, period = scenario()
        return build_dashboard(
            issues, [*sprints, *extra], MAPPING, period, now=dt(25), tz=UTC, bug_types=["Bug"]
        )

    def test_excluded_from_trend_charts(self) -> None:
        data = self._build(Sprint(11, "S11", "active", start=dt(19, 13), end=dt(2, month=2)))
        assert [r.sprint.id for r in data.sprints] == [10]
        assert data.velocity_trend == [8.0]
        assert data.active_sprint is not None
        assert data.active_sprint.sprint.id == 11

    def test_overdue_active_sprint_does_not_leak_into_tiles(self) -> None:
        # pianificato fino al 22 (dentro il periodo) ma ancora attivo il 25
        overdue = Sprint(11, "S11", "active", start=dt(19, 13), end=dt(22))
        tiles = {t.key: t for t in self._build(overdue).tiles}
        assert tiles["velocity"].value == 8
        assert tiles["say_do"].value == pytest.approx(1.0)

    def test_active_report_is_computed_at_now(self) -> None:
        overdue = Sprint(11, "S11", "active", start=dt(19, 13), end=dt(22))
        issues, sprints, period = scenario()
        done_today = make_issue(
            "C-1",
            story_points=4,
            transitions=[(dt(24), "Done")],
            sprint_ids=frozenset({11}),
            sprint_changes=[(dt(19), set(), {11})],
        )
        data = build_dashboard(
            [*issues, done_today],
            [*sprints, overdue],
            MAPPING,
            period,
            now=dt(25),
            tz=UTC,
            bug_types=["Bug"],
        )
        assert data.active_sprint is not None
        assert data.active_sprint.completed_points == 4

    def test_future_sprint_with_past_start_is_not_active(self) -> None:
        late_future = Sprint(12, "S12", "future", start=dt(20), end=dt(3, month=2))
        active = Sprint(11, "S11", "active", start=dt(19, 13), end=dt(2, month=2))
        data = self._build(active, late_future)
        assert data.active_sprint is not None
        assert data.active_sprint.sprint.id == 11
        assert [r.sprint.id for r in data.sprints] == [10]
