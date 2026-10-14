from datetime import date

import pytest

from recap.notes_parser import Commitment
from recap.store import CommitmentStore


@pytest.fixture
def store(tmp_path):
    return CommitmentStore(tmp_path / "commitments.json")


def test_new_store_is_empty(store):
    assert store.open_commitments() == []


def test_add_and_list_open_commitments_per_client(store):
    store.add("Acme", [Commitment("Maria", "send feedback", date(2026, 10, 20))], call_date=date(2026, 10, 14))
    store.add("Globex", [Commitment("Ana", "share plan", None)], call_date=date(2026, 10, 14))
    acme = store.open_commitments(client="Acme")
    assert [c.task for c in acme] == ["send feedback"]
    assert acme[0].client == "Acme"
    assert acme[0].due == date(2026, 10, 20)
    assert len(store.open_commitments()) == 2


def test_client_filter_is_case_insensitive(store):
    store.add("Acme", [Commitment("Maria", "send feedback", None)], call_date=date(2026, 10, 14))
    assert len(store.open_commitments(client="acme")) == 1


def test_ids_are_unique_and_mark_done_closes_commitment(store):
    added = store.add(
        "Acme",
        [Commitment("Maria", "send feedback", None), Commitment("Paolo", "confirm date", None)],
        call_date=date(2026, 10, 14),
    )
    assert added[0].id != added[1].id
    store.mark_done(added[0].id)
    assert [c.task for c in store.open_commitments()] == ["confirm date"]


def test_mark_done_unknown_id_raises(store):
    with pytest.raises(KeyError):
        store.mark_done(999)


def test_store_persists_to_disk(tmp_path):
    path = tmp_path / "commitments.json"
    CommitmentStore(path).add("Acme", [Commitment("Maria", "send feedback", date(2026, 10, 20))], call_date=date(2026, 10, 14))
    reopened = CommitmentStore(path).open_commitments()
    assert reopened[0].owner == "Maria"
    assert reopened[0].due == date(2026, 10, 20)


def test_open_commitments_sorted_by_due_date_with_undated_last(store):
    store.add(
        "Acme",
        [
            Commitment("A", "undated", None),
            Commitment("B", "later", date(2026, 11, 1)),
            Commitment("C", "sooner", date(2026, 10, 15)),
        ],
        call_date=date(2026, 10, 14),
    )
    assert [c.task for c in store.open_commitments()] == ["sooner", "later", "undated"]


def test_overdue(store):
    store.add(
        "Acme",
        [Commitment("A", "late", date(2026, 10, 10)), Commitment("B", "future", date(2026, 10, 30))],
        call_date=date(2026, 10, 1),
    )
    assert [c.task for c in store.overdue(today=date(2026, 10, 14))] == ["late"]
