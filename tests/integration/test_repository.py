from collections.abc import Iterator
from pathlib import Path

import pytest

from jira_kpi.storage.repository import IssueRepository
from tests.builders import dt


@pytest.fixture
def repo() -> Iterator[IssueRepository]:
    with IssueRepository(":memory:") as r:
        yield r


def raw(key: str, summary: str = "x") -> dict[str, object]:
    return {"key": key, "fields": {"summary": summary}}


def test_upsert_is_idempotent_and_replaces(repo: IssueRepository) -> None:
    repo.upsert([raw("A-1", "old"), raw("A-2")])
    repo.upsert([raw("A-1", "new")])
    loaded = {i["key"]: i for i in repo.load_all()}
    assert repo.count() == 2
    assert loaded["A-1"]["fields"]["summary"] == "new"


def test_last_sync_roundtrip(repo: IssueRepository) -> None:
    assert repo.last_sync() is None
    repo.set_last_sync(dt(5, 10))
    assert repo.last_sync() == dt(5, 10)


def test_scope_change_clears_data(repo: IssueRepository) -> None:
    assert repo.ensure_scope("project = A") is True  # primo utilizzo
    repo.upsert([raw("A-1")])
    repo.set_last_sync(dt(1))
    assert repo.ensure_scope("project = A") is False
    assert repo.count() == 1
    assert repo.ensure_scope("project = B") is True
    assert repo.count() == 0
    assert repo.last_sync() is None


def test_persists_on_disk(tmp_path: Path) -> None:
    db = tmp_path / "sub" / "kpi.sqlite"
    with IssueRepository(db) as r:
        r.upsert([raw("A-1")])
    with IssueRepository(db) as r:
        assert r.count() == 1
