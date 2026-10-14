from datetime import UTC, datetime, timedelta, timezone
from typing import Any

import pytest

from jira_kpi.jira.mapper import IssueMapper, parse_jira_datetime

MAPPER = IssueMapper(story_points_field="customfield_10016", sprint_field="customfield_10020")
CET = timezone(timedelta(hours=1))


class TestParseDatetime:
    @pytest.mark.parametrize(
        ("raw", "expected"),
        [
            ("2026-01-02T09:00:00.000+0100", datetime(2026, 1, 2, 9, tzinfo=CET)),
            ("2026-01-05T08:00:00.000Z", datetime(2026, 1, 5, 8, tzinfo=UTC)),
            ("2026-01-05T08:00:00+00:00", datetime(2026, 1, 5, 8, tzinfo=UTC)),
        ],
    )
    def test_formats(self, raw: str, expected: datetime) -> None:
        assert parse_jira_datetime(raw) == expected


class TestToIssue:
    def test_basic_fields(self, story_json: dict[str, Any]) -> None:
        issue = MAPPER.to_issue(story_json)
        assert issue.key == "PAY-42"
        assert issue.issue_type == "Story"
        assert issue.status == "Done"
        assert issue.priority == "High"
        assert issue.story_points == 5.0
        assert issue.created == datetime(2026, 1, 2, 9, tzinfo=CET)
        assert issue.sprint_ids == frozenset({10, 11})

    def test_status_transitions_sorted_and_filtered(self, story_json: dict[str, Any]) -> None:
        issue = MAPPER.to_issue(story_json)
        assert [(t.from_status, t.to_status) for t in issue.transitions] == [
            ("To Do", "In Progress"),
            ("In Progress", "Done"),
        ]
        assert issue.transitions[0].at == datetime(2026, 1, 6, 11, tzinfo=CET)

    def test_sprint_changes(self, story_json: dict[str, Any]) -> None:
        issue = MAPPER.to_issue(story_json)
        assert [(c.from_ids, c.to_ids) for c in issue.sprint_changes] == [
            (frozenset(), frozenset({10})),
            (frozenset({10}), frozenset({10, 11})),
        ]

    def test_missing_optional_fields(self, bug_json: dict[str, Any]) -> None:
        issue = MAPPER.to_issue(bug_json)
        assert issue.priority is None
        assert issue.story_points is None
        assert issue.sprint_ids == frozenset()
        assert issue.transitions == ()

    def test_sprint_changelog_matched_by_field_id_when_renamed(
        self, story_json: dict[str, Any]
    ) -> None:
        for history in story_json["changelog"]["histories"]:
            for item in history["items"]:
                if item["field"] == "Sprint":
                    item["field"] = "Iterazione"
        assert len(MAPPER.to_issue(story_json).sprint_changes) == 2


class TestExtractSprints:
    def test_unique_sprints_from_all_issues(
        self, story_json: dict[str, Any], bug_json: dict[str, Any]
    ) -> None:
        sprints = MAPPER.extract_sprints([story_json, bug_json, story_json])
        assert [s.id for s in sprints] == [10, 11]
        closed = sprints[0]
        assert closed.name == "PAY Sprint 10"
        assert closed.state == "closed"
        assert closed.start == datetime(2026, 1, 5, 8, tzinfo=UTC)
        assert closed.complete_date == datetime(2026, 1, 19, 9, 15, tzinfo=UTC)
        assert sprints[1].complete_date is None

    def test_board_filter(self, story_json: dict[str, Any]) -> None:
        mapper = IssueMapper("customfield_10016", "customfield_10020", board_id=99)
        assert mapper.extract_sprints([story_json]) == []
