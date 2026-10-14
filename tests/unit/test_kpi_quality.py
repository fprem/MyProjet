import pytest

from jira_kpi.domain.models import Period
from jira_kpi.kpi.quality import bug_ratio, bug_resolution_times, reopen_rate
from tests.builders import MAPPING, dt, make_issue

JAN = Period(dt(1), dt(1, month=2))
BUGS = frozenset({"Bug"})


class TestBugRatio:
    def test_bugs_created_over_issues_completed(self) -> None:
        issues = [
            make_issue("A-1", transitions=[(dt(3), "Done")]),
            make_issue("A-2", transitions=[(dt(4), "Done")]),
            make_issue("A-3", transitions=[(dt(5), "Done")]),
            make_issue("A-4", transitions=[(dt(6), "Done")]),
            make_issue("B-1", issue_type="Bug", created=dt(10)),
            make_issue("B-2", issue_type="bug", created=dt(1, month=2)),  # fuori periodo
        ]
        assert bug_ratio(issues, MAPPING, JAN, BUGS) == pytest.approx(0.25)

    def test_none_when_nothing_completed(self) -> None:
        assert bug_ratio([make_issue(issue_type="Bug")], MAPPING, JAN, BUGS) is None


class TestBugResolutionTimes:
    def test_grouped_by_priority(self) -> None:
        issues = [
            make_issue("B-1", issue_type="Bug", priority="High", transitions=[(dt(2), "Done")]),
            make_issue("B-2", issue_type="Bug", priority="High", transitions=[(dt(4), "Done")]),
            make_issue("B-3", issue_type="Bug", priority=None, transitions=[(dt(6), "Done")]),
            make_issue("S-1", issue_type="Story", priority="High", transitions=[(dt(9), "Done")]),
        ]
        result = bug_resolution_times(issues, MAPPING, JAN, BUGS)
        assert set(result) == {"High", "None"}
        assert result["High"].count == 2
        assert result["High"].p50 == pytest.approx(2.0)
        assert result["None"].p50 == pytest.approx(5.0)


class TestReopenRate:
    def test_share_of_completed_issues_that_were_reopened(self) -> None:
        issues = [
            make_issue(
                "A-1", transitions=[(dt(3), "Done"), (dt(4), "In Progress"), (dt(5), "Done")]
            ),
            make_issue("A-2", transitions=[(dt(3), "Done")]),
            make_issue("A-3", transitions=[(dt(3), "Done"), (dt(4), "In Progress")]),  # aperta
        ]
        assert reopen_rate(issues, MAPPING, JAN) == pytest.approx(0.5)

    def test_none_when_nothing_completed(self) -> None:
        assert reopen_rate([], MAPPING, JAN) is None
