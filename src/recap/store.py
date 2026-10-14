"""A JSON-file list of commitments per client, open until marked done."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path

from recap.notes_parser import Commitment


@dataclass
class StoredCommitment:
    id: int
    client: str
    owner: str | None
    task: str
    due: date | None
    call_date: date
    done: bool = False

    def to_json(self) -> dict:
        data = asdict(self)
        data["due"] = self.due.isoformat() if self.due else None
        data["call_date"] = self.call_date.isoformat()
        return data

    @classmethod
    def from_json(cls, data: dict) -> StoredCommitment:
        return cls(
            **{
                **data,
                "due": date.fromisoformat(data["due"]) if data["due"] else None,
                "call_date": date.fromisoformat(data["call_date"]),
            }
        )


class CommitmentStore:
    def __init__(self, path: str | Path):
        self.path = Path(path)
        self._items: list[StoredCommitment] = []
        if self.path.exists():
            self._items = [StoredCommitment.from_json(d) for d in json.loads(self.path.read_text())]

    def _save(self) -> None:
        self.path.write_text(json.dumps([c.to_json() for c in self._items], indent=2))

    def add(self, client: str, commitments: list[Commitment], call_date: date) -> list[StoredCommitment]:
        next_id = max((c.id for c in self._items), default=0) + 1
        added = [
            StoredCommitment(next_id + i, client, c.owner, c.task, c.due, call_date)
            for i, c in enumerate(commitments)
        ]
        self._items.extend(added)
        self._save()
        return added

    def mark_done(self, commitment_id: int) -> None:
        for c in self._items:
            if c.id == commitment_id:
                c.done = True
                self._save()
                return
        raise KeyError(commitment_id)

    def open_commitments(self, client: str | None = None) -> list[StoredCommitment]:
        items = [
            c for c in self._items
            if not c.done and (client is None or c.client.casefold() == client.casefold())
        ]
        return sorted(items, key=lambda c: (c.due is None, c.due or date.max, c.id))

    def overdue(self, today: date, client: str | None = None) -> list[StoredCommitment]:
        return [c for c in self.open_commitments(client) if c.due and c.due < today]
