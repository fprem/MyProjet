from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest

from jira_kpi.cli import main
from jira_kpi.config import Settings
from jira_kpi.jira.client import JiraAuthError
from jira_kpi.storage.repository import IssueRepository
from tests.builders import dt


class StubClient:
    def __init__(self, fail: bool = False) -> None:
        self.fail = fail

    def __enter__(self) -> "StubClient":
        return self

    def __exit__(self, *exc: object) -> None:
        return None

    def search_issues(self, jql: str, fields: list[str]) -> Iterator[dict[str, Any]]:
        if self.fail:
            raise JiraAuthError("credenziali rifiutate")
        yield {"key": "PAY-1", "fields": {}, "changelog": {"histories": [], "total": 0}}

    def get_changelog(self, key: str) -> list[dict[str, Any]]:
        return []

    def get_fields(self) -> list[dict[str, Any]]:
        return [
            {"id": "customfield_10016", "name": "Story point estimate", "custom": True},
            {"id": "customfield_10020", "name": "Sprint", "custom": True},
            {"id": "customfield_10001", "name": "Team", "custom": True},
            {"id": "summary", "name": "Summary", "custom": False},
        ]


@pytest.fixture
def config(tmp_path: Path) -> Path:
    path = tmp_path / "config.yaml"
    path.write_text(
        "jira_url: https://acme.atlassian.net\nproject: PAY\nteam: t1\n"
        f"db_path: {tmp_path / 'kpi.sqlite'}\n"
    )
    return path


def test_sync_command(config: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code = main(
        ["sync", "--config", str(config)], client_factory=lambda s: StubClient(), now=dt(10)
    )
    assert code == 0
    assert "1 issue" in capsys.readouterr().out
    with IssueRepository(tmp_path / "kpi.sqlite") as repo:
        assert repo.count() == 1


def test_sync_reports_auth_error(config: Path, capsys: pytest.CaptureFixture[str]) -> None:
    code = main(
        ["sync", "--config", str(config)],
        client_factory=lambda s: StubClient(fail=True),
        now=dt(10),
    )
    assert code == 2
    assert "credenziali" in capsys.readouterr().err


def test_discover_fields_lists_relevant_custom_fields(
    config: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    assert (
        main(["discover-fields", "--config", str(config)], client_factory=lambda s: StubClient())
        == 0
    )
    out = capsys.readouterr().out
    assert "customfield_10016" in out
    assert "customfield_10001" in out
    assert "summary" not in out


def test_demo_command_populates_database(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    db = tmp_path / "demo.sqlite"
    assert main(["demo", "--db", str(db)], now=dt(14, month=10)) == 0
    with IssueRepository(db) as repo:
        assert repo.count() > 50
    assert str(db) in capsys.readouterr().out


def test_missing_config_file(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["sync", "--config", "/nope.yaml"]) == 2
    assert "nope.yaml" in capsys.readouterr().err


def test_default_client_factory_requires_credentials(
    config: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.delenv("JIRA_EMAIL", raising=False)
    monkeypatch.delenv("JIRA_API_TOKEN", raising=False)
    monkeypatch.chdir(config.parent)  # nessun .env
    assert main(["sync", "--config", str(config)]) == 2
    assert "JIRA_API_TOKEN" in capsys.readouterr().err


def test_settings_type_for_factory(config: Path) -> None:
    seen: list[Settings] = []

    def factory(settings: Settings) -> StubClient:
        seen.append(settings)
        return StubClient()

    main(["sync", "--config", str(config)], client_factory=factory, now=dt(10))
    assert seen[0].project == "PAY"
