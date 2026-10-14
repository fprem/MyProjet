from dataclasses import FrozenInstanceError, replace
from datetime import datetime

import pytest

from jira_kpi.domain.models import (
    Period,
    Sprint,
    StatusCategory,
    StatusMapping,
    StatusTransition,
)
from tests.builders import dt, make_issue


class TestStatusMapping:
    def test_lookup_is_case_and_whitespace_insensitive(self) -> None:
        mapping = StatusMapping({"In Progress": StatusCategory.IN_PROGRESS})
        assert mapping.category("  in progress ") is StatusCategory.IN_PROGRESS

    def test_unknown_status_falls_back_to_default(self) -> None:
        mapping = StatusMapping({}, default=StatusCategory.WAITING)
        assert mapping.category("Whatever") is StatusCategory.WAITING

    def test_default_fallback_is_todo(self) -> None:
        assert StatusMapping({}).category("X") is StatusCategory.TODO


class TestStatusTransition:
    def test_requires_timezone_aware_datetime(self) -> None:
        with pytest.raises(ValueError, match="timezone"):
            StatusTransition(at=datetime(2026, 1, 1), from_status="To Do", to_status="Done")

    def test_is_immutable(self) -> None:
        t = StatusTransition(at=dt(1), from_status="To Do", to_status="Done")
        with pytest.raises(FrozenInstanceError):
            t.to_status = "X"  # type: ignore[misc]


class TestIssue:
    def test_transitions_are_sorted_chronologically(self) -> None:
        issue = make_issue(transitions=[(dt(3), "In Progress"), (dt(5), "Done")])
        reordered = replace(issue, transitions=tuple(reversed(issue.transitions)))
        assert [t.at for t in reordered.transitions] == [dt(3), dt(5)]

    def test_requires_timezone_aware_created(self) -> None:
        with pytest.raises(ValueError, match="timezone"):
            make_issue(created=datetime(2026, 1, 1))

    def test_points_default_to_zero_when_missing(self) -> None:
        assert make_issue(story_points=None).points == 0.0
        assert make_issue(story_points=3).points == 3.0


class TestPeriod:
    def test_contains_is_half_open(self) -> None:
        period = Period(dt(1), dt(8))
        assert period.contains(dt(1))
        assert period.contains(dt(7, 23))
        assert not period.contains(dt(8))

    def test_end_must_be_after_start(self) -> None:
        with pytest.raises(ValueError, match="end"):
            Period(dt(8), dt(1))

    def test_previous_has_same_length_and_ends_at_start(self) -> None:
        assert Period(dt(8), dt(15)).previous() == Period(dt(1), dt(8))


class TestSprintState:
    @pytest.mark.parametrize(
        ("state", "complete_date", "closed", "active"),
        [
            ("closed", dt(19), True, False),
            ("closed", None, True, False),
            ("active", None, False, True),
            ("ACTIVE", None, False, True),
            ("future", None, False, False),
            ("active", dt(19), True, False),  # completeDate prevale
        ],
    )
    def test_closed_and_active(
        self, state: str, complete_date: datetime | None, closed: bool, active: bool
    ) -> None:
        sprint = Sprint(1, "S", state, start=dt(5), end=dt(19), complete_date=complete_date)
        assert sprint.is_closed is closed
        assert sprint.is_active is active
