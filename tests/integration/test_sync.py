from collections.abc import Iterator
from typing import Any

import pytest

from jira_kpi.config import Settings
from jira_kpi.storage.repository import IssueRepository
from jira_kpi.sync import sync
from tests.builders import dt

SETTINGS = Settings.model_validate(
    {"jira_url": "https://acme.atlassian.net", "project": "PAY", "team": "t1", "timezone": "UTC"}
)


class FakeClient:
    def __init__(self, issues: list[dict[str, Any]], changelogs: dict[str, list[Any]]) -> None:
        self.issues = issues
        self.changelogs = changelogs
        self.queries: list[tuple[str, list[str]]] = []
        self.changelog_calls: list[str] = []

    def search_issues(self, jql: str, fields: list[str]) -> Iterator[dict[str, Any]]:
        self.queries.append((jql, fields))
        yield from self.issues

    def get_changelog(self, key: str) -> list[dict[str, Any]]:
        self.changelog_calls.append(key)
        return self.changelogs[key]


def issue(key: str, histories: int = 0, total: int | None = None) -> dict[str, Any]:
    hs = [{"id": str(n)} for n in range(histories)]
    return {
        "key": key,
        "fields": {},
        "changelog": {"histories": hs, "total": histories if total is None else total},
    }


@pytest.fixture
def repo() -> Iterator[IssueRepository]:
    with IssueRepository(":memory:") as r:
        yield r


def test_first_sync_is_full(repo: IssueRepository) -> None:
    client = FakeClient([issue("A-1"), issue("A-2")], {})
    result = sync(client, repo, SETTINGS, now=dt(10))
    assert result.fetched == 2
    assert result.full is True
    jql, fields = client.queries[0]
    assert jql == SETTINGS.jql
    assert {"status", "created", "issuetype", "customfield_10016", "customfield_10020"} <= set(
        fields
    )
    assert repo.last_sync() == dt(10)
    assert repo.count() == 2


def test_incremental_sync_uses_updated_with_safety_margin(repo: IssueRepository) -> None:
    sync(FakeClient([issue("A-1")], {}), repo, SETTINGS, now=dt(10, 15))
    client = FakeClient([issue("A-3")], {})
    result = sync(client, repo, SETTINGS, now=dt(11))
    assert result.full is False
    assert client.queries[0][0] == f'({SETTINGS.jql}) AND updated >= "2026-01-09 15:00"'
    assert result.total == 2


def test_full_flag_forces_full_resync(repo: IssueRepository) -> None:
    sync(FakeClient([issue("A-1")], {}), repo, SETTINGS, now=dt(10))
    client = FakeClient([issue("A-2")], {})
    result = sync(client, repo, SETTINGS, now=dt(11), full=True)
    assert result.full is True
    assert client.queries[0][0] == SETTINGS.jql
    assert {i["key"] for i in repo.load_all()} == {"A-2"}  # dati obsoleti rimossi


def test_truncated_changelog_is_fetched_in_full(repo: IssueRepository) -> None:
    full_history = [{"id": str(n)} for n in range(150)]
    client = FakeClient(
        [issue("A-1", histories=100, total=150), issue("A-2", 3)], {"A-1": full_history}
    )
    sync(client, repo, SETTINGS, now=dt(10))
    assert client.changelog_calls == ["A-1"]
    stored = {i["key"]: i for i in repo.load_all()}
    assert len(stored["A-1"]["changelog"]["histories"]) == 150
