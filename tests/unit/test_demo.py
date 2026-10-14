from jira_kpi.demo import DEMO_MAPPING, demo_settings, generate_raw_issues
from jira_kpi.jira.mapper import IssueMapper
from tests.builders import dt

NOW = dt(14, 12, month=10)


def test_is_deterministic() -> None:
    assert generate_raw_issues(NOW, seed=1) == generate_raw_issues(NOW, seed=1)
    assert generate_raw_issues(NOW, seed=1) != generate_raw_issues(NOW, seed=2)


def test_output_is_valid_jira_json() -> None:
    settings = demo_settings()
    mapper = IssueMapper(settings.story_points_field, settings.sprint_field)
    raws = generate_raw_issues(NOW)
    issues = [mapper.to_issue(r) for r in raws]
    sprints = mapper.extract_sprints(raws)
    assert len(issues) > 50
    assert {s.state for s in sprints} >= {"closed", "active"}
    assert {i.issue_type for i in issues} >= {"Story", "Bug"}
    assert all(DEMO_MAPPING.category(i.status) for i in issues)


def test_no_events_in_the_future() -> None:
    mapper = IssueMapper("customfield_10016", "customfield_10020")
    for raw in generate_raw_issues(NOW):
        issue = mapper.to_issue(raw)
        assert issue.created <= NOW
        assert all(t.at <= NOW for t in issue.transitions)
        assert all(c.at <= NOW for c in issue.sprint_changes)
        if issue.transitions:
            assert issue.transitions[-1].to_status == issue.status
