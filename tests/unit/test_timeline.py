from datetime import timedelta

from jira_kpi.domain.models import StatusCategory
from jira_kpi.domain.timeline import (
    build_timeline,
    category_at,
    completed_at,
    cycle_started_at,
    was_reopened,
)
from tests.builders import MAPPING, dt, make_issue


class TestBuildTimeline:
    def test_issue_never_transitioned_has_single_open_interval(self) -> None:
        issue = make_issue(created=dt(1))
        timeline = build_timeline(issue, MAPPING)
        assert len(timeline) == 1
        assert timeline[0].status == "To Do"
        assert timeline[0].start == dt(1)
        assert timeline[0].end is None

    def test_intervals_follow_transitions(self) -> None:
        issue = make_issue(transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        timeline = build_timeline(issue, MAPPING)
        assert [(i.status, i.start, i.end) for i in timeline] == [
            ("To Do", dt(1), dt(2)),
            ("In Progress", dt(2), dt(4)),
            ("Done", dt(4), None),
        ]
        assert [i.category for i in timeline] == [
            StatusCategory.TODO,
            StatusCategory.IN_PROGRESS,
            StatusCategory.DONE,
        ]

    def test_out_of_order_transitions_are_sorted(self) -> None:
        issue = make_issue(transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        shuffled = issue.with_transitions(tuple(reversed(issue.transitions)))
        assert [i.status for i in build_timeline(shuffled, MAPPING)] == [
            "To Do",
            "In Progress",
            "Done",
        ]

    def test_interval_duration(self) -> None:
        issue = make_issue(transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        assert build_timeline(issue, MAPPING)[1].duration() == timedelta(days=2)
        assert build_timeline(issue, MAPPING)[2].duration(now=dt(5)) == timedelta(days=1)


class TestCycleStart:
    def test_first_entry_into_active_state(self) -> None:
        issue = make_issue(
            transitions=[(dt(2), "In Progress"), (dt(3), "To Do"), (dt(5), "In Progress")]
        )
        assert cycle_started_at(issue, MAPPING) == dt(2)

    def test_waiting_counts_as_started(self) -> None:
        issue = make_issue(transitions=[(dt(3), "Waiting for QA")])
        assert cycle_started_at(issue, MAPPING) == dt(3)

    def test_never_started(self) -> None:
        assert cycle_started_at(make_issue(), MAPPING) is None

    def test_jump_straight_to_done_has_no_cycle_start(self) -> None:
        issue = make_issue(transitions=[(dt(3), "Done")])
        assert cycle_started_at(issue, MAPPING) is None


class TestCompletedAt:
    def test_done_issue(self) -> None:
        issue = make_issue(transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        assert completed_at(issue, MAPPING) == dt(4)

    def test_open_issue_is_not_completed(self) -> None:
        issue = make_issue(transitions=[(dt(2), "In Progress")])
        assert completed_at(issue, MAPPING) is None

    def test_reopened_then_done_uses_last_done(self) -> None:
        issue = make_issue(
            transitions=[
                (dt(2), "In Progress"),
                (dt(4), "Done"),
                (dt(5), "In Progress"),
                (dt(7), "Done"),
            ]
        )
        assert completed_at(issue, MAPPING) == dt(7)

    def test_reopened_and_still_open_is_not_completed(self) -> None:
        issue = make_issue(transitions=[(dt(4), "Done"), (dt(5), "In Progress")])
        assert completed_at(issue, MAPPING) is None

    def test_created_directly_in_done_state(self) -> None:
        issue = make_issue(created=dt(3), initial_status="Done")
        assert completed_at(issue, MAPPING) == dt(3)


class TestReopened:
    def test_detects_move_out_of_done(self) -> None:
        issue = make_issue(transitions=[(dt(4), "Done"), (dt(5), "In Progress")])
        assert was_reopened(issue, MAPPING)

    def test_plain_flow_is_not_reopened(self) -> None:
        issue = make_issue(transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        assert not was_reopened(issue, MAPPING)


class TestCategoryAt:
    def test_before_creation_is_none(self) -> None:
        issue = make_issue(created=dt(3))
        assert category_at(issue, MAPPING, dt(2)) is None

    def test_category_at_instant(self) -> None:
        issue = make_issue(transitions=[(dt(2), "In Progress"), (dt(4), "Done")])
        assert category_at(issue, MAPPING, dt(1, 12)) is StatusCategory.TODO
        assert category_at(issue, MAPPING, dt(2)) is StatusCategory.IN_PROGRESS
        assert category_at(issue, MAPPING, dt(10)) is StatusCategory.DONE
