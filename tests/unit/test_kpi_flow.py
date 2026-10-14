from datetime import date, timedelta
from zoneinfo import ZoneInfo

import pytest

from jira_kpi.domain.models import Period, StatusCategory
from jira_kpi.kpi.flow import (
    aging_wip,
    cumulative_flow,
    cycle_times,
    daily_wip,
    duration_stats,
    flow_efficiency,
    lead_times,
    percentile,
    throughput,
)
from tests.builders import MAPPING, dt, make_issue

JAN = Period(dt(1), dt(1, month=2))


class TestPercentile:
    @pytest.mark.parametrize(
        ("values", "p", "expected"),
        [
            ([5.0], 50, 5.0),
            ([1.0, 2.0, 3.0, 4.0], 50, 2.5),
            ([1.0, 2.0, 3.0, 4.0, 5.0], 85, 4.4),
            ([3.0, 1.0, 2.0], 100, 3.0),
            ([3.0, 1.0, 2.0], 0, 1.0),
        ],
    )
    def test_linear_interpolation(self, values: list[float], p: float, expected: float) -> None:
        assert percentile(values, p) == pytest.approx(expected)

    def test_empty_raises(self) -> None:
        with pytest.raises(ValueError):
            percentile([], 50)

    def test_out_of_range_raises(self) -> None:
        with pytest.raises(ValueError):
            percentile([1.0], 101)


class TestDurationStats:
    def test_empty_is_none(self) -> None:
        assert duration_stats([]) is None

    def test_summary(self) -> None:
        stats = duration_stats([1.0, 2.0, 3.0, 4.0])
        assert stats is not None
        assert stats.count == 4
        assert stats.mean == pytest.approx(2.5)
        assert stats.p50 == pytest.approx(2.5)
        assert stats.p85 == pytest.approx(3.55)
        assert stats.p95 == pytest.approx(3.85)


class TestCycleAndLeadTime:
    def test_cycle_time_in_days_for_issues_completed_in_period(self) -> None:
        done = make_issue("A-1", transitions=[(dt(2), "In Progress"), (dt(5, 12), "Done")])
        open_ = make_issue("A-2", transitions=[(dt(2), "In Progress")])
        skipped = make_issue("A-3", transitions=[(dt(3), "Done")])  # mai avviata
        outside = make_issue(
            "A-4",
            transitions=[(dt(2), "In Progress"), (dt(3, month=2), "Done")],
        )
        result = cycle_times([done, open_, skipped, outside], MAPPING, JAN)
        assert [(r.key, r.days) for r in result] == [("A-1", pytest.approx(3.5))]
        assert result[0].completed_at == dt(5, 12)

    def test_lead_time_counts_from_creation(self) -> None:
        issue = make_issue(created=dt(1), transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        skipped = make_issue("A-3", created=dt(1), transitions=[(dt(3), "Done")])
        result = lead_times([issue, skipped], MAPPING, JAN)
        assert sorted(r.days for r in result) == [2.0, 3.0]

    def test_results_sorted_by_completion(self) -> None:
        a = make_issue("A-1", transitions=[(dt(2), "In Progress"), (dt(9), "Done")])
        b = make_issue("A-2", transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        assert [r.key for r in cycle_times([a, b], MAPPING, JAN)] == ["A-2", "A-1"]


class TestThroughput:
    def test_weekly_counts_including_empty_weeks(self) -> None:
        # Settimane ISO: 2025-12-29 (lun), 2026-01-05, 2026-01-12
        issues = [
            make_issue("A-1", transitions=[(dt(2), "Done")]),
            make_issue("A-2", transitions=[(dt(4), "Done")]),
            make_issue("A-3", transitions=[(dt(13), "Done")]),
            make_issue("A-4", transitions=[(dt(13), "In Progress")]),
        ]
        period = Period(dt(1), dt(15))
        assert throughput(issues, MAPPING, period, ZoneInfo("UTC")) == [
            (date(2025, 12, 29), 2),
            (date(2026, 1, 5), 0),
            (date(2026, 1, 12), 1),
        ]

    def test_uses_local_timezone_for_week_boundaries(self) -> None:
        # Domenica 4 gennaio 23:30 UTC = lunedì 5 gennaio 00:30 a Roma
        issue = make_issue(transitions=[(dt(4, 23) + timedelta(minutes=30), "Done")])
        period = Period(dt(1), dt(12))
        result = throughput([issue], MAPPING, period, ZoneInfo("Europe/Rome"))
        assert dict(result)[date(2026, 1, 5)] == 1


class TestCumulativeFlowAndWip:
    def test_category_counts_at_end_of_each_day(self) -> None:
        a = make_issue(
            "A-1", created=dt(1), transitions=[(dt(2, 10), "In Progress"), (dt(3, 10), "Done")]
        )
        b = make_issue("A-2", created=dt(2, 9), transitions=[(dt(2, 11), "Waiting for QA")])
        period = Period(dt(1), dt(4))
        cfd = cumulative_flow([a, b], MAPPING, period, ZoneInfo("UTC"))
        assert [d for d, _ in cfd] == [date(2026, 1, 1), date(2026, 1, 2), date(2026, 1, 3)]
        assert cfd[0][1] == {StatusCategory.TODO: 1}
        assert cfd[1][1] == {StatusCategory.IN_PROGRESS: 1, StatusCategory.WAITING: 1}
        assert cfd[2][1] == {StatusCategory.DONE: 1, StatusCategory.WAITING: 1}

    def test_daily_wip_counts_started_not_done(self) -> None:
        a = make_issue("A-1", transitions=[(dt(2, 10), "In Progress"), (dt(3, 10), "Done")])
        b = make_issue("A-2", transitions=[(dt(2, 11), "Waiting for QA")])
        period = Period(dt(1), dt(4))
        assert daily_wip([a, b], MAPPING, period, ZoneInfo("UTC")) == [
            (date(2026, 1, 1), 0),
            (date(2026, 1, 2), 2),
            (date(2026, 1, 3), 1),
        ]


class TestFlowEfficiency:
    def test_active_over_total_cycle_time(self) -> None:
        # 2 giorni attivi, 2 giorni in attesa -> 50%
        a = make_issue(
            "A-1",
            transitions=[
                (dt(2), "In Progress"),
                (dt(3), "Waiting for QA"),
                (dt(5), "Code Review"),
                (dt(6), "Done"),
            ],
        )
        # 1 giorno attivo -> totale 3 attivi su 5 = 60%
        b = make_issue("A-2", transitions=[(dt(2), "In Progress"), (dt(3), "Done")])
        assert flow_efficiency([a, b], MAPPING, JAN) == pytest.approx(0.6)

    def test_time_back_in_todo_counts_as_waiting(self) -> None:
        a = make_issue(
            "A-1",
            transitions=[
                (dt(2), "In Progress"),
                (dt(3), "To Do"),
                (dt(4), "In Progress"),
                (dt(5), "Done"),
            ],
        )
        assert flow_efficiency([a], MAPPING, JAN) == pytest.approx(2 / 3)

    def test_no_completed_issues_is_none(self) -> None:
        assert flow_efficiency([make_issue()], MAPPING, JAN) is None


class TestAgingWip:
    def test_age_of_started_open_issues_sorted_oldest_first(self) -> None:
        young = make_issue("A-1", transitions=[(dt(8), "In Progress")])
        old = make_issue("A-2", transitions=[(dt(2), "Waiting for QA")])
        done = make_issue("A-3", transitions=[(dt(2), "In Progress"), (dt(3), "Done")])
        todo = make_issue("A-4")
        result = aging_wip([young, old, done, todo], MAPPING, now=dt(10))
        assert [(a.key, a.status, a.age_days) for a in result] == [
            ("A-2", "Waiting for QA", 8.0),
            ("A-1", "In Progress", 2.0),
        ]
