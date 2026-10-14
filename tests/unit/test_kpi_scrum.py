import pytest

from jira_kpi.domain.models import Sprint
from jira_kpi.kpi.scrum import rolling_average, sprint_report, sprint_reports, sprints_at
from tests.builders import MAPPING, dt, make_issue

SPRINT = Sprint(
    id=10, name="Sprint 10", state="closed", start=dt(5), end=dt(19), complete_date=dt(19, 12)
)


class TestSprintsAt:
    def test_reconstructs_membership_from_changelog(self) -> None:
        issue = make_issue(
            sprint_ids=frozenset({10, 11}),
            sprint_changes=[(dt(3), set(), {10}), (dt(19, 12), {10}, {10, 11})],
        )
        assert sprints_at(issue, dt(2)) == frozenset()
        assert sprints_at(issue, dt(3)) == frozenset({10})
        assert sprints_at(issue, dt(10)) == frozenset({10})
        assert sprints_at(issue, dt(20)) == frozenset({10, 11})

    def test_without_changes_uses_current_value(self) -> None:
        issue = make_issue(sprint_ids=frozenset({10}))
        assert sprints_at(issue, dt(1)) == frozenset({10})


def committed(key: str, points: float, transitions=None, **kw):  # type: ignore[no-untyped-def]
    return make_issue(
        key,
        story_points=points,
        transitions=transitions or [],
        sprint_ids=frozenset({10}),
        sprint_changes=[(dt(4), set(), {10})],
        **kw,
    )


class TestSprintReport:
    def test_commitment_completion_and_carry_over(self) -> None:
        done = committed("A-1", 5, [(dt(6), "In Progress"), (dt(10), "Done")])
        not_done = make_issue(
            "A-2",
            story_points=3,
            transitions=[(dt(6), "In Progress")],
            sprint_ids=frozenset({10, 11}),
            sprint_changes=[(dt(4), set(), {10}), (dt(19, 12), {10}, {10, 11})],
        )
        added_done = make_issue(
            "A-3",
            story_points=2,
            transitions=[(dt(12), "Done")],
            sprint_ids=frozenset({10}),
            sprint_changes=[(dt(8), set(), {10})],
        )
        removed = make_issue(
            "A-4",
            story_points=8,
            sprint_ids=frozenset(),
            sprint_changes=[(dt(4), set(), {10}), (dt(9), {10}, set())],
        )
        unrelated = make_issue("B-1", story_points=13, sprint_ids=frozenset({99}))

        report = sprint_report(SPRINT, [done, not_done, added_done, removed, unrelated], MAPPING)

        assert report.committed_points == 16  # 5 + 3 + 8
        assert report.committed_count == 3
        assert report.added_points == 2
        assert report.removed_points == 8
        assert report.completed_points == 7  # velocity: 5 + 2
        assert report.completed_count == 2
        assert report.carried_over_count == 1
        assert report.carried_over_points == 3
        # say/do: punti completati tra quelli committati / punti committati
        assert report.say_do_ratio == pytest.approx(5 / 16)

    def test_issue_done_after_sprint_end_is_not_completed(self) -> None:
        late = committed("A-1", 5, [(dt(20), "Done")])
        report = sprint_report(SPRINT, [late], MAPPING)
        assert report.completed_points == 0
        assert report.carried_over_count == 1

    def test_missing_story_points_count_as_zero(self) -> None:
        report = sprint_report(SPRINT, [committed("A-1", None, [(dt(6), "Done")])], MAPPING)  # type: ignore[arg-type]
        assert report.committed_count == 1
        assert report.committed_points == 0
        assert report.say_do_ratio is None

    def test_sprint_without_dates_is_rejected(self) -> None:
        with pytest.raises(ValueError, match="date"):
            sprint_report(Sprint(id=1, name="Future", state="future"), [], MAPPING)


class TestSprintReports:
    def test_only_closed_sprints_ordered_by_start(self) -> None:
        earlier = Sprint(id=9, name="Sprint 9", state="closed", start=dt(1), end=dt(5))
        active = Sprint(id=11, name="Sprint 11", state="active", start=dt(19, 13), end=dt(2, 2))
        future = Sprint(id=12, name="Sprint 12", state="future")
        reports = sprint_reports([active, future, SPRINT, earlier], [], MAPPING)
        assert [r.sprint.id for r in reports] == [9, 10]


class TestRollingAverage:
    def test_window_of_three(self) -> None:
        assert rolling_average([3.0, 6.0, 9.0, 12.0], 3) == [3.0, 4.5, 6.0, 9.0]

    def test_empty(self) -> None:
        assert rolling_average([], 3) == []


class TestSprintReportAsOf:
    def test_as_of_overrides_planned_end(self) -> None:
        active = Sprint(10, "S10", "active", start=dt(5), end=dt(19))
        late_done = committed("A-1", 5, [(dt(20), "Done")])
        late_added = make_issue(
            "A-2",
            story_points=3,
            sprint_ids=frozenset({10}),
            sprint_changes=[(dt(20), set(), {10})],
        )
        report = sprint_report(active, [late_done, late_added], MAPPING, as_of=dt(21))
        assert report.completed_points == 5
        assert report.added_points == 3

    def test_scope_points_excludes_removed(self) -> None:
        kept = committed("A-1", 20)
        removed = make_issue(
            "A-2",
            story_points=5,
            sprint_ids=frozenset(),
            sprint_changes=[(dt(4), set(), {10}), (dt(9), {10}, set())],
        )
        report = sprint_report(SPRINT, [kept, removed], MAPPING)
        assert report.scope_points == 20
